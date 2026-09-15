import java.io.File;
import java.nio.file.*;
import java.util.*;

// Runs against the actual Processing-preprocessed classes, without an OpenGL window.
public class ReplayChecks {
  static void check(boolean ok, String message) {
    if (!ok) throw new AssertionError(message);
  }
  static void state(Opinionarium.World w, int round) {
    check(w.stateRound == round, "wrong committed round");
    Opinionarium.ReplayRound rr = w.data.rounds[round];
    check(w.connections.size() == rr.edges.size(), "wrong network size");
    for (int i=0; i<w.agents.size(); i++) {
      check(w.agents.get(i).belief == rr.states[i], "state not from recorded snapshot");
    }
    for (int i=0; i<rr.edges.size(); i++) {
      int[] e=rr.edges.get(i);
      check(w.connections.get(i).follower == w.agents.get(e[0]) &&
            w.connections.get(i).followed == w.agents.get(e[1]), "network mismatch");
    }
  }
  static void complete(Opinionarium.World w, float speed) {
    w.player.speed=speed;
    w.player.paused=false;
    int guard=0, maxParticles=0;
    int lastCommit=0;
    while (!w.player.ended() && guard++ < 200000) {
      w.player.update(0.1f);
      maxParticles=Math.max(maxParticles,w.messages.size());
      int expected=w.player.phase == 3 ? w.player.activeRound : w.player.completedRound;
      state(w,expected);
      if (w.stateRound != lastCommit) {
        check(w.stateRound == lastCommit+1,"skipped/repeated commit");
        lastCommit=w.stateRound;
      }
    }
    check(w.player.ended(),"never finished");
    check(w.player.totalDelivered == w.data.totalExposures,"lost/repeated exposure");
    check(maxParticles <= w.player.MAX_PARTICLES,"particle cap exceeded");
    state(w,w.data.lastRound());
    System.out.println("Complete: speed="+speed+", exposures="+w.player.totalDelivered+", max particles="+maxParticles);
  }
  static void write(Path dir, String file, String value) throws Exception {
    Files.writeString(dir.resolve(file),value);
  }
  public static void main(String[] args) throws Exception {
    Opinionarium app=new Opinionarium();
    app.width=1440; app.height=900;
    java.lang.reflect.Field sketchPath=processing.core.PApplet.class.getDeclaredField("sketchPath");
    sketchPath.setAccessible(true); sketchPath.set(app,Path.of("").toAbsolutePath().toString());
    Opinionarium.ReplayData data=app.new ReplayLoader().load(new File(args[0]));
    app.world=app.new World(data);
    Opinionarium.World w=app.world;
    check(data.size()==500 && data.lastRound()==50,"wrong fixture");
    check(data.totalExposures==40570,"wrong event total");
    float x=w.agents.get(0).position.x;
    // Pause and single-step must preserve synchronous boundaries at every phase.
    w.player.step();
    boolean[] checked=new boolean[4];
    for (int guard=0; !w.player.paused && guard<10000;guard++) {
      int phase=w.player.phase;
      if (!checked[phase]) {
        checked[phase]=true;
        float t=w.player.visualTime;
        int delivered=w.player.totalDelivered, round=w.stateRound;
        w.player.paused=true; w.player.update(3);
        check(t==w.player.visualTime && delivered==w.player.totalDelivered && round==w.stateRound,"pause advanced");
        w.player.paused=false;
      }
      w.player.update(0.1f);
    }
    check(w.player.completedRound==1 && w.player.paused,"step did not stop at next boundary");
    for (boolean phase:checked) check(phase,"missing phase test");
    w.reset(); complete(w,1);
    w.reset(); check(w.agents.get(0).position.x==x,"replay changed layout");
    complete(w,8);
    // View operations must not affect the data or playback.
    w.layout.zoomAt(400,300,-3); w.layout.resetView();
    check(w.layout.zoom==1 && w.player.ended(),"view altered playback");
    // A non-contiguous-ID, zero-message recording exercises empty rounds.
    Path dir=Files.createTempDirectory(Path.of("build"),"empty-fixture-");
    write(dir,"manifest.json","{\"scenario\":\"test\",\"orientation\":\"none\",\"seed\":1,\"rounds\":1,\"agent_count\":2,\"model_revision\":\"fixture\",\"leader_ids\":[]}");
    String states="round,agent_id,a,b,signed_mean\n0,7,2,2,0\n0,42,2,2,0\n1,7,2,2,0\n1,42,2,2,0\n";
    write(dir,"states.csv",states);
    write(dir,"origination.csv","round,agent_id,did_originate,origination_probability,message_id\n1,7,False,0,\n1,42,False,0,\n");
    write(dir,"messages.csv","round,message_id,producer_id,stance\n");
    write(dir,"exposures.csv","round,consumer_id,message_id,producer_id,stance\n");
    write(dir,"network.csv","round,consumer_id,producer_id\n");
    write(dir,"aggregates.csv","round,consumer_id,n_support,n_oppose,weighted_support,weighted_oppose,a_before,b_before,a_after,b_after\n1,7,0,0,0,0,2,2,2,2\n1,42,0,0,0,0,2,2,2,2\n");
    Opinionarium.ReplayData empty=app.new ReplayLoader().load(dir.toFile());
    app.world=app.new World(empty);
    complete(app.world,1);
    write(dir,"states.csv",states.replace("1,42,2,2,0\n",""));
    boolean rejected=false;
    try { app.new ReplayLoader().load(dir.toFile()); } catch (IllegalArgumentException e) { rejected=e.getMessage().contains("missing node"); }
    check(rejected,"missing state accepted");
    write(dir,"states.csv",states);
    write(dir,"messages.csv","round,message_id,producer_id,stance\n1,m,7,0\n");
    rejected=false;
    try { app.new ReplayLoader().load(dir.toFile()); } catch (IllegalArgumentException e) { rejected=true; }
    check(rejected,"invalid stance accepted");
    System.out.println("PASS: full replay, speed invariance, pause, step, reset, empty rounds, arbitrary IDs, malformed data");
  }
}
