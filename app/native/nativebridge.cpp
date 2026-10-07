#include "nativebridge.h"
#include "backend/computermanager.h"
#include "backend/boxartmanager.h"
#include "cli/startstream.h"
#include "settings/streamingpreferences.h"
#include "streaming/session.h"
#include <QCoreApplication>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QMetaProperty>
#include <QMetaEnum>
#include <QQuickWindow>
#include <QScreen>
#include <QSocketNotifier>
#include <QTimer>
#include <QRegularExpression>
#include <QReadLocker>
#include <fcntl.h>
#include <unistd.h>
#include <cerrno>
#include <cstdio>
#include <cmath>

namespace {
QString artKey(const QString& uuid, int id) { return uuid + ':' + QString::number(id); }
bool editable(const QMetaProperty& p) {
    const QByteArray name(p.name());
    return p.isWritable() && name != "objectName" && name != "language" &&
           name != "uiDisplayMode" && name != "recommendedFullScreenMode";
}
}

NativeBridge::NativeBridge(const QStringList& args, QObject* parent) : QObject(parent),
    m_Preferences(StreamingPreferences::get()),
    m_Manager(new ComputerManager(m_Preferences)),
    m_Input(new QSocketNotifier(STDIN_FILENO, QSocketNotifier::Read, this))
{
    m_StreamMode = args.size() > 2 && args[2] == "stream";
    m_TestMode = args.size() > 2 && args[2] == "test";
    const int flags = fcntl(STDIN_FILENO, F_GETFL);
    if (flags == -1 || fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK) == -1) {
        QTimer::singleShot(0, this, [this] { error("Cannot open native command channel."); QCoreApplication::exit(1); });
        return;
    }
    connect(m_Input, &QSocketNotifier::activated, this, [this] { readInput(); });
    connect(m_Manager.get(), &ComputerManager::computerStateChanged, this, [this] { snapshot(); });
    connect(m_Manager.get(), &ComputerManager::computerAddCompleted, this, [this](QVariant success, QVariant blocked) {
        send({{"event", "hostAdded"}, {"success", success.toBool()}, {"blockedPorts", blocked.toInt()}});
        if (!success.toBool()) error("Could not connect to this computer. Check its address, Local Network access and the host's streaming service.");
        snapshot();
    });
    connect(m_Manager.get(), &ComputerManager::pairingCompleted, this, [this](NvComputer*, QString message) {
        m_Pairing = false;
        send({{"event", "paired"}, {"success", message.isEmpty()}});
        if (!message.isEmpty()) error(message);
        snapshot();
    });
    connect(m_Manager.get(), &ComputerManager::quitAppCompleted, this, [this](QVariant message) {
        if (!message.toString().isEmpty()) error(message.toString());
        else send({{"event", "appQuit"}});
    });
    createArtworkManager();
    QTimer::singleShot(0, this, [this, args] {
        send({{"event", "ready"}, {"protocol", 1}, {"engineVersion", QCoreApplication::applicationVersion()}});
        if (m_StreamMode) startStream(args);
        else {
            preferences();
            snapshot();
            if (!m_TestMode) { m_Manager->startPolling(); m_Polling = true; }
        }
    });
}

NativeBridge::~NativeBridge() = default;

void NativeBridge::send(QJsonObject event) {
    const QByteArray data = QJsonDocument(event).toJson(QJsonDocument::Compact) + '\n';
    // Pipe writes are serialized on the main thread. Ignore SIGPIPE in main;
    // a vanished frontend ends this helper instead of retaining discovery.
    if (fwrite(data.constData(), 1, size_t(data.size()), stdout) != size_t(data.size()) || fflush(stdout) != 0)
        QCoreApplication::exit(1);
}
void NativeBridge::error(QString message) { send({{"event", "error"}, {"message", message}}); }

void NativeBridge::readInput() {
    char chunk[4096];
    for (;;) {
        const ssize_t count = read(STDIN_FILENO, chunk, sizeof(chunk));
        if (count == 0) { m_Input->setEnabled(false); QCoreApplication::quit(); return; }
        if (count < 0) {
            if (errno == EINTR) continue;
            if (errno != EAGAIN && errno != EWOULDBLOCK) { error("Command channel failed."); QCoreApplication::exit(1); }
            break;
        }
        m_Buffer.append(chunk, int(count));
        if (m_Buffer.size() > 1024 * 1024) { error("Command exceeds the size limit."); QCoreApplication::exit(1); return; }
        int newline;
        while ((newline = m_Buffer.indexOf('\n')) >= 0) {
            const QByteArray line = m_Buffer.left(newline);
            m_Buffer.remove(0, newline + 1);
            QJsonParseError parseError;
            const auto document = QJsonDocument::fromJson(line, &parseError);
            if (parseError.error != QJsonParseError::NoError || !document.isObject()) error("Invalid JSON command.");
            else command(document.object());
        }
    }
}

NvComputer* NativeBridge::findComputer(QString uuid) {
    for (auto computer : m_Manager->getComputers()) {
        QReadLocker guard(&computer->lock);
        if (computer->uuid == uuid) return computer;
    }
    return nullptr;
}

void NativeBridge::command(const QJsonObject& request) {
    const QString action = request["command"].toString();
    if (action == "shutdown") { QCoreApplication::quit(); return; }
    if (m_StreamMode) {
        if (action == "confirmQuit" && m_Launcher && !m_Streaming) m_Launcher->quitRunningApp();
        else error("This command is unavailable during streaming.");
        return;
    }
    if (action == "snapshot") { snapshot(); preferences(); return; }
    if (action == "settings") {
        if (!request["values"].isObject()) error("Settings must be an object.");
        else if (setPreferences(request["values"].toObject())) preferences();
        return;
    }
    if (m_TestMode) { error("Network operations are disabled in test mode."); return; }
    if (action == "pause") {
        if (m_Polling) { m_Manager->stopPollingAsync(); m_Polling = false; }
        send({{"event", "paused"}}); return;
    }
    if (action == "resume") {
        // The streaming helper can update pairing/server metadata. Reloading a
        // second ComputerManager would invalidate pointers, so use our existing
        // manager's ordinary polling to refresh the live computer state.
        if (!m_Polling) { m_Manager->startPolling(); m_Polling = true; }
        snapshot(); return;
    }
    if (action == "addHost") {
        const QString address = request["address"].toString().trimmed();
        if (address.isEmpty() || address.size() > 253 || address.contains(QRegularExpression("[\\s/\\\\]"))) error("Enter a hostname or IP address, optionally followed by a port.");
        else m_Manager->addNewHostManually(address);
        return;
    }
    auto computer = findComputer(request["host"].toString());
    if (!computer) { error("This computer is no longer available."); return; }
    if (action == "pair") {
        const QString pin = request["pin"].toString();
        if (m_Pairing) { error("A pairing request is already in progress."); return; }
        if (!QRegularExpression("^[0-9]{4}$").match(pin).hasMatch()) { error("The pairing PIN must contain four digits."); return; }
        { QReadLocker guard(&computer->lock);
          if (computer->state != NvComputer::CS_ONLINE) { error("The computer must be online before pairing."); return; }
          if (computer->pairState == NvComputer::PS_PAIRED) { error("This computer is already paired."); return; }
        }
        m_Pairing = true;
        m_Manager->pairHost(computer, pin);
    } else if (action == "wake") {
        QReadLocker guard(&computer->lock);
        if (!computer->wake()) error("Could not send Wake on LAN. Check that the host has a valid hardware address.");
    } else if (action == "quitApp") m_Manager->quitRunningApp(computer);
    else if (action == "rename") {
        const QString name = request["name"].toString().trimmed();
        if (name.isEmpty() || name.size() > 100) error("Enter a computer name between 1 and 100 characters.");
        else m_Manager->renameHost(computer, name);
    } else if (action == "remove") {
        if (m_Pairing) { error("Wait for pairing to finish before removing a computer."); return; }
        // Upstream artwork tasks retain the host pointer. Drain them before
        // deleting it, and disconnect queued artwork completions with their owner.
        m_Artwork.reset();
        m_Manager->deleteHost(computer);
        m_ArtworkRequested.clear();
        m_ArtworkUrls.clear();
        createArtworkManager();
        snapshot();
    } else error("Unknown native command.");
}

void NativeBridge::createArtworkManager() {
    m_Artwork.reset(new BoxArtManager());
    connect(m_Artwork.get(), &BoxArtManager::boxArtLoadComplete, m_Artwork.get(), [this](NvComputer* computer, NvApp app, QUrl url) {
        QReadLocker guard(&computer->lock);
        const QString key = artKey(computer->uuid, app.id);
        m_ArtworkUrls[key] = url.toString();
        send({{"event", "artwork"}, {"host", computer->uuid}, {"app", app.id}, {"url", url.toString()}});
    });
}

void NativeBridge::snapshot() {
    if (m_StreamMode) return;
    QJsonArray hosts;
    for (auto computer : m_Manager->getComputers()) {
        QReadLocker guard(&computer->lock);
        QJsonArray apps;
        for (auto app : computer->appList) {
            const QString key = artKey(computer->uuid, app.id);
            if (!m_TestMode && computer->state == NvComputer::CS_ONLINE && computer->pairState == NvComputer::PS_PAIRED && !m_ArtworkRequested.contains(key)) {
                m_ArtworkRequested.insert(key);
                auto url = m_Artwork->loadBoxArt(computer, app);
                if (url.isLocalFile()) m_ArtworkUrls[key] = url.toString();
            }
            apps.append(QJsonObject{{"id", app.id}, {"name", app.name}, {"hdr", app.hdrSupported}, {"hidden", app.hidden}, {"artwork", m_ArtworkUrls.value(key)}});
        }
        hosts.append(QJsonObject{{"id", computer->uuid}, {"name", computer->name},
            {"online", computer->state == NvComputer::CS_ONLINE}, {"unknown", computer->state == NvComputer::CS_UNKNOWN},
            {"paired", computer->pairState == NvComputer::PS_PAIRED}, {"runningApp", computer->currentGameId},
            {"address", computer->activeAddress.toString()}, {"localAddress", computer->localAddress.toString()},
            {"serverVersion", computer->appVersion}, {"gpu", computer->gpuModel},
            {"supported", computer->isSupportedServerVersion}, {"apps", apps}});
    }
    send({{"event", "hosts"}, {"hosts", hosts}});
}

void NativeBridge::preferences() {
    QJsonObject values;
    QJsonArray schema;
    const auto meta = m_Preferences->metaObject();
    for (int i = meta->propertyOffset(); i < meta->propertyCount(); ++i) {
        auto property = meta->property(i);
        if (!editable(property)) continue;
        values[property.name()] = property.isEnumType() ? QJsonValue(property.read(m_Preferences).toInt()) : QJsonValue::fromVariant(property.read(m_Preferences));
        QJsonArray choices;
        if (property.isEnumType()) {
            const auto e = property.enumerator();
            for (int j = 0; j < e.keyCount(); ++j) {
                if (e.value(j) < 0 || QByteArray(e.key(j)).contains("DEPRECATED")) continue;
                choices.append(QJsonObject{{"value", e.value(j)}, {"name", e.key(j)}});
            }
        }
        schema.append(QJsonObject{{"id", property.name()}, {"boolean", property.metaType().id() == QMetaType::Bool}, {"choices", choices}});
    }
    send({{"event", "settings"}, {"values", values}, {"schema", schema}});
}

bool NativeBridge::setPreferences(const QJsonObject& values) {
    if (m_Pairing) { error("Wait for pairing to finish before changing settings."); return false; }
    const QHash<QString, QPair<int,int>> ranges = {{"width", {320, 16384}}, {"height", {240, 16384}}, {"fps", {10, 480}}, {"bitrateKbps", {500, 500000}}};
    // Validate the entire transaction before mutating any existing preference.
    for (auto it = values.begin(); it != values.end(); ++it) {
        const auto meta = m_Preferences->metaObject();
        int index = meta->indexOfProperty(it.key().toUtf8().constData());
        if (index < 0 || !editable(meta->property(index))) { error("Unknown or read-only setting: " + it.key()); return false; }
        auto p = meta->property(index);
        if (p.metaType().id() == QMetaType::Bool) {
            if (!it.value().isBool()) { error("Expected a Boolean for " + it.key()); return false; }
        } else {
            double number = it.value().toDouble(-1);
            if (!it.value().isDouble() || !std::isfinite(number) || std::floor(number) != number || number < 0 || number > 500000) { error("Invalid numeric setting: " + it.key()); return false; }
            if (p.isEnumType() && !p.enumerator().valueToKey(int(number))) { error("Invalid choice for " + it.key()); return false; }
            if (ranges.contains(it.key()) && (number < ranges[it.key()].first || number > ranges[it.key()].second)) { error("Setting is out of range: " + it.key()); return false; }
        }
    }
    const bool mdnsChanged = values.contains("enableMdns") && values["enableMdns"].toBool() != m_Preferences->enableMdns;
    if (mdnsChanged && m_Polling) { m_Manager->stopPollingAsync(); m_Polling = false; }
    for (auto it = values.begin(); it != values.end(); ++it) m_Preferences->setProperty(it.key().toUtf8().constData(), it.value().toVariant());
    if (m_Preferences->autoAdjustBitrate && !values.contains("bitrateKbps") && (values.contains("width") || values.contains("height") || values.contains("fps") || values.contains("enableYUV444")))
        m_Preferences->bitrateKbps = StreamingPreferences::getDefaultBitrate(m_Preferences->width, m_Preferences->height, m_Preferences->fps, m_Preferences->enableYUV444);
    m_Preferences->save();
    if (mdnsChanged && !m_TestMode) { m_Manager->startPolling(); m_Polling = true; }
    return true;
}

void NativeBridge::startStream(const QStringList& args) {
    if (args.size() != 7 || args[3].isEmpty() || args[4].isEmpty()) { error("Invalid native stream arguments."); QCoreApplication::exit(1); return; }
    bool xValid, yValid;
    const int x = args[5].toInt(&xValid), y = args[6].toInt(&yValid);
    if (!xValid || !yValid) { error("Invalid display coordinates."); QCoreApplication::exit(1); return; }
    m_Window.reset(new QQuickWindow());
    for (auto screen : QGuiApplication::screens()) {
        if (screen->geometry().contains(x, y)) { m_Window->setScreen(screen); break; }
    }
    m_Window->setGeometry(x, y, 960, 640);
    // A hidden window conveys upstream's display-selection contract. It never
    // owns or wraps the SDL streaming video surface and loads no QML frontend.
    m_Launcher = new CliStartStream::Launcher(args[3], args[4], m_Preferences, this);
    connect(m_Launcher, &CliStartStream::Launcher::failed, this, [this](QString message) { error(message); QCoreApplication::exit(1); });
    connect(m_Launcher, &CliStartStream::Launcher::searchingComputer, this, [this] { send({{"event", "stage"}, {"message", "Connecting to computer…"}}); });
    connect(m_Launcher, &CliStartStream::Launcher::searchingApp, this, [this] { send({{"event", "stage"}, {"message", "Loading game…"}}); });
    connect(m_Launcher, &CliStartStream::Launcher::appQuitRequired, this, [this](QString app) { send({{"event", "quitRequired"}, {"app", app}}); });
    connect(m_Launcher, &CliStartStream::Launcher::sessionCreated, this, [this](QString, Session* session) {
        connect(session, &Session::stageStarting, this, [this](QString stage) { send({{"event", "stage"}, {"message", "Starting " + stage + "…"}}); });
        connect(session, &Session::stageFailed, this, [this](QString stage, int code, QString ports) { error(QString("Starting %1 failed (error %2). %3").arg(stage).arg(code).arg(ports.isEmpty() ? QString() : "Check these ports: " + ports)); });
        connect(session, &Session::displayLaunchError, this, [this](QString message) { error(message); });
        connect(session, &Session::connectionStarted, this, [this] { m_Streaming = true; send({{"event", "streaming"}}); });
        connect(session, &Session::sessionFinished, this, [this](int ports) { send({{"event", "finished"}, {"portTest", ports}}); });
        connect(session, &Session::readyForDeletion, this, [session] { session->deleteLater(); QCoreApplication::quit(); });
        if (!session->initialize(m_Window.get())) {
            error("The streaming session could not initialize. See the engine log for details.");
            session->deleteLater(); QCoreApplication::exit(1); return;
        }
        for (const auto& warning : session->property("launchWarnings").toStringList()) send({{"event", "warning"}, {"message", warning}});
        QTimer::singleShot(0, session, &Session::start);
    });
    m_Launcher->execute(m_Manager.get());
}
