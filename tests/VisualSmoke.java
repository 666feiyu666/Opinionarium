import processing.core.PApplet;

// Render actual P2D frames: initial, typical, dense network, and final state.
public class VisualSmoke extends Opinionarium {
  long start;
  double sumFPS=0;
  float minFPS=Float.MAX_VALUE;
  int samples=0;
  public void setup() {
    super.setup(); start=System.nanoTime();
    System.out.println("DISPLAY "+displayWidth+"x"+displayHeight+" canvas "+width+"x"+height+" pixel "+pixelWidth+"x"+pixelHeight);
  }
  void report(String stage) {
    System.out.println(stage+": avg FPS="+sumFPS/Math.max(1,samples)+", min FPS="+minFPS+
      ", heap MB="+(Runtime.getRuntime().totalMemory()-Runtime.getRuntime().freeMemory())/1048576+
      ", elapsed s="+(System.nanoTime()-start)/1e9+", live particles="+world.messages.size());
    sumFPS=0; samples=0; minFPS=Float.MAX_VALUE;
  }
  public void draw() {
    super.draw();
    if (!loadError.isEmpty()) { System.err.println(loadError); exit(); return; }
    if (world == null) return;
    if (frameCount == 5) { saveFrame("out/initial-500.png"); world.player.toggle(); }
    if (frameCount == 180) saveFrame("out/propagation-500.png");
    if (frameCount == 240) {
      world.selectedAgent=world.agents.get(0); world.selectedAgent.selected=true;
    }
    if (frameCount == 241) saveFrame("out/inspector-500.png");
    if (frameCount > 90 && frameCount < 660) {
      sumFPS+=frameRate; minFPS=Math.min(minFPS,frameRate); samples++;
    }
    if (frameCount == 360) {
      report("TYPICAL");
      int dense=1;
      for (int r=2;r<=world.data.lastRound();r++)
        if (world.data.rounds[r].exposures.size()>world.data.rounds[dense].exposures.size()) dense=r;
      world.reset(); world.selectedAgent=null;
      for (Agent a:world.agents) a.selected=false;
      world.applyState(dense-1,false); world.player.completedRound=dense-1;
      world.showFullNetwork=true; world.player.toggle();
      System.out.println("DENSE round="+dense+" exposures="+world.data.rounds[dense].exposures.size());
    }
    if (frameCount == 540) saveFrame("out/dense-network-500.png");
    if (frameCount == 660) {
      report("DENSE WITH NETWORK");
      world.showFullNetwork=false;
      // Exercise the real controller through the remaining rounds before final rendering.
      while (!world.player.ended()) world.player.update(1);
    }
    if (frameCount == 662) saveFrame("out/final-500.png");
    if (frameCount == 675) {
      System.out.println("FINAL round="+world.stateRound+" edges="+world.connections.size());
      exit();
    }
  }
  // The scripted visual check should not be steered by incidental input.
  public void keyPressed() {}
  public void mouseDragged() {}
  public void mouseReleased() {}
  public void mouseWheel(processing.event.MouseEvent event) {}
  public static void main(String[] args) { PApplet.main("VisualSmoke"); }
}
