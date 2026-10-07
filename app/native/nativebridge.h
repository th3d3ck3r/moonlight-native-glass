#pragma once

#include <QObject>
#include <QByteArray>
#include <QJsonObject>
#include <QHash>
#include <QSet>
#include <memory>

class ComputerManager;
class BoxArtManager;
class StreamingPreferences;
class QSocketNotifier;
class QQuickWindow;
class NvComputer;
namespace CliStartStream { class Launcher; }

// macOS-only presentation adapter. The transport and Session implementations
// remain upstream's; stdout carries versioned JSON lines, never shell commands.
class NativeBridge : public QObject
{
public:
    explicit NativeBridge(const QStringList& arguments, QObject* parent);
    ~NativeBridge() override;

private:
    void send(QJsonObject event);
    void error(QString message);
    void readInput();
    void command(const QJsonObject& request);
    void snapshot();
    void preferences();
    bool setPreferences(const QJsonObject& values);
    void createArtworkManager();
    NvComputer* findComputer(QString uuid);
    void startStream(const QStringList& arguments);

    StreamingPreferences* m_Preferences;
    std::unique_ptr<ComputerManager> m_Manager;
    std::unique_ptr<BoxArtManager> m_Artwork;
    std::unique_ptr<QQuickWindow> m_Window;
    QSocketNotifier* m_Input;
    CliStartStream::Launcher* m_Launcher = nullptr;
    QByteArray m_Buffer;
    QHash<QString, QString> m_ArtworkUrls;
    QSet<QString> m_ArtworkRequested;
    bool m_Polling = false;
    bool m_StreamMode = false;
    bool m_TestMode = false;
    bool m_Streaming = false;
    bool m_Pairing = false;
};
