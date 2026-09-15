import java.io.File;
import java.util.*;

World world;
String loadError="";
volatile String pendingDirectory;
int previousMillis;
float pressX,pressY;
boolean dragging=false;
boolean loading=false;
boolean resumeAfterChooser=false;

void settings() {
  size(min(1440,displayWidth-80),min(900,displayHeight-100),P2D);
  pixelDensity(1);
  smooth(4);
}
void setup() {
  surface.setTitle("Opinionarium");
  frameRate(60);
  textFont(createFont("SansSerif",13,true));
  pendingDirectory=System.getProperty("opinionarium.data",dataPath("baseline_positive_20260910_50"));
  previousMillis=millis();
}

void draw() {
  background(18,20,27);
  int now=millis();
  float dt=min((now-previousMillis)/1000.0,0.1);
  previousMillis=now;
  if (pendingDirectory != null) {
    String path=pendingDirectory; pendingDirectory=null;
    try {
      ReplayData data=new ReplayLoader().load(new File(path));
      World candidate=new World(data);
      world=candidate; loadError="";
    } catch (Exception e) {
      loadError=e.getMessage(); println(loadError);
    }
    loading=false; previousMillis=millis();
  }
  if (world != null) {
    if (!loading && loadError.isEmpty()) world.player.update(dt);
    world.display();
  }
  displayHeader();
  if (!loadError.isEmpty()) {
    noStroke(); fill(18,20,27,245); rect(40,140,width-360,230,8);
    fill(238,173,100); textAlign(LEFT,TOP); textSize(18); text("Could not load recording",62,160);
    fill(217); textSize(12); text(loadError,62,198,width-412,132);
    text("L: choose another data folder"+(world != null ? "     ESC: return to previous recording" : ""),62,338);
  }
}

void displayHeader() {
  noStroke(); fill(18,20,27); rect(0,0,width,82);
  fill(244); textAlign(LEFT,TOP); textSize(24); text("OPINIONARIUM",22,15);
  fill(145,155,174); textSize(11);
  text("SPACE play / pause    RIGHT step    R replay    +/- speed    E network    L load    V fit    Scroll zoom / drag pan",23,53);
  if (world == null) return;
  PlaybackController p=world.player;
  textAlign(RIGHT,TOP); textSize(13); fill(p.paused ? color(238,173,100) : color(104,211,151));
  text(loading ? "SELECT FOLDER" : p.ended() ? "COMPLETE" : p.paused ? "PAUSED" : "PLAYING",width-228,23);
  fill(207); text(nf(p.speed,0,2)+"x",width-154,23);
  text("Round "+max(p.activeRound,p.completedRound)+" / "+world.data.lastRound(),width-22,23);
}
void keyPressed() {
  if (key == ESC) { key=0; loadError=""; return; }
  if (key == 'l' || key == 'L') {
    if (!loading) {
      loading=true;
      resumeAfterChooser=world != null && !world.player.paused;
      if (world != null) world.player.paused=true;
      selectFolder("Choose a folder containing states.csv and manifest.json","folderSelected");
    }
    return;
  }
  if (world == null || loading || !loadError.isEmpty()) return;
  if (key == ' ') world.player.toggle();
  else if (keyCode == RIGHT) world.player.step();
  else if (key == 'r' || key == 'R') world.reset();
  else if (key == 'e' || key == 'E') world.showFullNetwork=!world.showFullNetwork;
  else if (key == '+' || key == '=') world.player.speed=constrain(world.player.speed+0.25,0.25,8);
  else if (key == '-' || key == '_') world.player.speed=constrain(world.player.speed-0.25,0.25,8);
  else if (key == 'v' || key == 'V') world.layout.resetView();
  else if (key == 's' || key == 'S') saveFrame("out/opinionarium-####.png");
}
void folderSelected(File folder) {
  if (folder != null) pendingDirectory=folder.getAbsolutePath();
  else {
    loading=false;
    if (world != null && resumeAfterChooser) world.player.paused=false;
  }
}
void mousePressed() { pressX=mouseX; pressY=mouseY; dragging=false; }
void mouseDragged() {
  if (world == null || loading || pressX >= width-world.PANEL_WIDTH || pressY < 82) return;
  if (dist(mouseX,mouseY,pressX,pressY) > 4) dragging=true;
  if (dragging) { world.layout.panX+=mouseX-pmouseX; world.layout.panY+=mouseY-pmouseY; }
}
void mouseReleased() {
  if (world != null && !dragging && !loading) world.selectAgentAt(mouseX,mouseY);
}
void mouseWheel(processing.event.MouseEvent event) {
  if (world != null && mouseX < width-world.PANEL_WIDTH && mouseY >= 82) world.layout.zoomAt(mouseX,mouseY,event.getCount());
}
