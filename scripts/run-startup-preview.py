"""Launch the actual Startup Preview product and export its finite startup."""
from pathlib import Path
import subprocess,sys,time
app=Path(sys.argv[1]).resolve();output=Path(sys.argv[2]).resolve();output.mkdir(parents=True,exist_ok=True)
process=subprocess.Popen([str(app/'Contents/MacOS/MoonlightLG'),'--design-preview','--boot-preview','--dark'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
try:
    time.sleep(.8)
    assert process.poll() is None,'Startup Preview exited during arrival'
    subprocess.run(['screencapture','-x',str(output/'startup-arrival.png')],check=True)
    time.sleep(8)
    assert process.poll() is None,'Startup Preview exited before its library handoff'
    subprocess.run(['screencapture','-x',str(output/'startup-library.png')],check=True)
    print('PASS: built Startup Preview launched and remained alive across arrival and library handoff; captures exported')
finally:
    if process.poll() is None:
        process.terminate()
        try:process.wait(timeout=5)
        except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)
