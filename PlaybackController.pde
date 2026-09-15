class PlaybackController {
  final World owner;
  // 0 boundary, 1 origination, 2 delivery, 3 synchronous commit / settling.
  int phase = 0, completedRound = 0, activeRound = 0;
  int nextExposure = 0, delivered = 0, totalDelivered = 0;
  boolean paused = true, stopAfterRound = false;
  float speed = 1, elapsed = 0, visualTime = 0;
  final int MAX_PARTICLES = 64;

  PlaybackController(World owner) { this.owner=owner; }
  boolean ended() { return completedRound == owner.data.lastRound() && phase == 0; }
  void toggle() { if (!ended()) { paused=!paused; stopAfterRound=false; } }
  void step() { if (!ended()) { paused=false; stopAfterRound=true; } }
  void beginRound() {
    activeRound=completedRound+1;
    phase=1; elapsed=0; nextExposure=delivered=0;
    ReplayRound rr=owner.data.rounds[activeRound];
    for (int i=0;i<owner.agents.size();i++) {
      Agent a=owner.agents.get(i);
      a.speaking=false;
      if (rr.origins[i].posted) a.beginSpeaking();
    }
  }
  void update(float seconds) {
    if (paused || ended()) return;
    // Fixed substeps keep phase boundaries reliable even at high playback speeds.
    float remaining=seconds*speed;
    while (remaining > 0 && !paused && !ended()) {
      float dt=min(remaining,0.025);
      tick(dt); remaining-=dt;
    }
  }
  void tick(float dt) {
    visualTime+=dt;
    for (Agent a : owner.agents) a.update(dt);
    if (phase == 0) { beginRound(); return; }
    elapsed+=dt;
    ReplayRound rr=owner.data.rounds[activeRound];
    if (phase == 1) {
      if (elapsed >= 0.55) { phase=2; elapsed=0; }
      return;
    }
    if (phase == 2) {
      for (int i=owner.messages.size()-1;i>=0;i--) {
        Message m=owner.messages.get(i);
        m.update(dt);
        if (m.readyToDeliver()) {
          m.receiver.arrivalFlash=1;
          m.markDelivered();
          delivered++; totalDelivered++;
        }
        if (m.finished()) owner.messages.remove(i);
      }
      // Each recorded exposure is queued once; batches have no causal meaning.
      if (owner.messages.isEmpty() && nextExposure < rr.exposures.size()) {
        int end=min(nextExposure+MAX_PARTICLES,rr.exposures.size());
        while (nextExposure < end) {
          RecordedExposure e=rr.exposures.get(nextExposure++);
          owner.messages.add(new Message(owner.agents.get(e.message.producer),
            owner.agents.get(e.consumer),e.message.stance,e.message.id,activeRound));
        }
      }
      if (nextExposure == rr.exposures.size() && owner.messages.isEmpty()) {
        owner.applyState(activeRound,true);
        phase=3; elapsed=0;
        for (Agent a : owner.agents) a.speaking=false;
      }
      return;
    }
    if (phase == 3 && elapsed >= 0.85) {
      completedRound=activeRound; phase=0; elapsed=0;
      // End transitions exactly at the recorded visual targets.
      for (Agent a : owner.agents) { a.displayedOpinion=a.opinion; a.displayRadius=a.targetRadius; }
      if (stopAfterRound || ended()) { paused=true; stopAfterRound=false; }
    }
  }
  String label() {
    if (ended()) return "COMPLETE";
    if (phase == 1) return "ORIGINATING";
    if (phase == 2) return "DELIVERING";
    if (phase == 3) return "UPDATING";
    return completedRound == 0 ? "READY" : "ROUND COMPLETE";
  }
}
