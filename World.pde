class World {
  final ReplayData data;
  ArrayList<Agent> agents = new ArrayList<Agent>();
  ArrayList<Connection> connections = new ArrayList<Connection>();
  ArrayList<Message> messages = new ArrayList<Message>();
  Agent selectedAgent;
  Layout layout;
  PlaybackController player;
  boolean showFullNetwork=false;
  int stateRound=0;
  float radiusScale;
  final float PANEL_WIDTH=280;

  World(ReplayData data) {
    this.data=data;
    float w=width-PANEL_WIDTH, h=height-120;
    radiusScale=constrain(sqrt(w*h/(float)data.size())/35,0.55,1.6);
    layout=new Layout(data.size(),w,h);
    player=new PlaybackController(this);
    for (int i=0;i<data.size();i++) {
      agents.add(new Agent(data.ids[i],layout.positions[i],data.rounds[0].states[i].opinion(),
        data.leaders.contains(data.ids[i]),radiusScale));
    }
    int[] maxFollowers=new int[data.size()];
    for (ReplayRound rr : data.rounds) {
      int[] degree=new int[data.size()];
      for (int[] edge : rr.edges) degree[edge[1]]++;
      for (int i=0;i<degree.length;i++) maxFollowers[i]=max(maxFollowers[i],degree[i]);
    }
    float[] radii=new float[data.size()];
    for (int i=0;i<radii.length;i++) radii[i]=agents.get(i).radiusForFollowerCount(maxFollowers[i])+(agents.get(i).leader ? 5*radiusScale : 0);
    layout.separate(radii);
    applyState(0,false);
  }
  void reset() {
    messages.clear(); player=new PlaybackController(this);
    layout.resetView();
    for (Agent a:agents) {
      a.arrivalFlash=a.degreePulse=a.emissionPulse=0; a.speaking=false;
    }
    applyState(0,false);
  }
  void applyState(int round, boolean animate) {
    stateRound=round;
    ReplayRound rr=data.rounds[round];
    connections.clear();
    int[] followers=new int[data.size()];
    int[] following=new int[data.size()];
    for (int[] edge:rr.edges) {
      connections.add(new Connection(agents.get(edge[0]),agents.get(edge[1])));
      following[edge[0]]++; followers[edge[1]]++;
    }
    for (int i=0;i<agents.size();i++) {
      Agent a=agents.get(i);
      a.belief=rr.states[i]; a.opinion=a.belief.opinion(); a.following=following[i];
      a.setFollowerCount(followers[i],animate);
      if (!animate) a.displayedOpinion=a.opinion;
    }
  }
  void display() {
    clip(0,82,int(width-PANEL_WIDTH),height-120);
    pushMatrix();
    layout.transform();
    for (Connection c:connections) c.display(showFullNetwork,selectedAgent);
    for (Message m:messages) m.display();
    for (Agent a:agents) if (a != selectedAgent) a.display();
    if (selectedAgent != null) selectedAgent.display();
    popMatrix();
    noClip();
    displayInspector();
    displayFooter();
  }
  void selectAgentAt(float x,float y) {
    if (x >= width-PANEL_WIDTH || y < 82 || y > height-38) return;
    PVector p=layout.local(x,y);
    selectedAgent=null;
    float nearest=Float.MAX_VALUE;
    for (Agent a:agents) {
      float distance=dist(p.x,p.y,a.position.x,a.position.y);
      if (a.containsPoint(p.x,p.y) && distance < nearest) { selectedAgent=a; nearest=distance; }
    }
    for (Agent a:agents) a.selected=a == selectedAgent;
  }
  void field(String title,String value,float y) {
    textAlign(LEFT,TOP); fill(143,152,170); text(title,width-PANEL_WIDTH+22,y);
    textAlign(RIGHT,TOP); fill(230,234,240); text(value,width-22,y);
  }
  void displayInspector() {
    float x=width-PANEL_WIDTH;
    noStroke(); fill(25,28,37); rect(x,82,PANEL_WIDTH,height-82);
    textAlign(LEFT,TOP); textSize(11); fill(140,154,175);
    text("RECORDED SIMULATION",x+22,106);
    textSize(18); fill(236); text(data.scenario+" / "+data.orientation,x+22,128);
    textSize(12);
    field("Agents",str(data.size()),170);
    field("Opinion leaders",str(data.leaders.size()),194);
    field("Relationships",str(connections.size()),218);
    field("Committed state","Round "+stateRound,242);
    stroke(56,62,77); line(x+22,276,width-22,276); noStroke();
    textAlign(LEFT,TOP); fill(236); textSize(16);
    text(selectedAgent == null ? "Explore an agent" : "Agent "+selectedAgent.id,x+22,298);
    textSize(12);
    if (selectedAgent == null) {
      fill(146,156,174);
      text("Click a node to inspect its belief,\nmessages and relationships.\n\nScroll to zoom. Drag to pan.\nV resets the view.",x+22,334);
    } else {
      Agent a=selectedAgent;
      int i=data.index.get(a.id);
      field("Role",a.leader ? "Opinion leader" : "Ordinary",334);
      field("Signed belief",nf(a.opinion,1,4),360);
      field("Beta a / b",String.format(java.util.Locale.US,"%.3f / %.3f",a.belief.a,a.belief.b),386);
      field("Concentration",String.format(java.util.Locale.US,"%.3f",a.belief.a+a.belief.b),412);
      field("Followers / following",a.followerCount+" / "+a.following,438);
      int r=player.activeRound;
      if (r > 0) {
        ReplayRound rr=data.rounds[r];
        field("Round "+r+" posted",rr.origins[i].posted ? "Yes" : "No",478);
        field("Posting probability",nf((float)rr.origins[i].probability,1,3),504);
        RecordedEvidence e=rr.evidence[i];
        field("Round "+r+" received (+ / -)",e.support+" / "+e.oppose,530);
        field("Evidence weight (+ / -)",nf((float)e.weightedSupport,1,2)+" / "+nf((float)e.weightedOppose,1,2),556);
      }
    }
    float y=height-182;
    textAlign(LEFT,TOP); fill(145,156,177); textSize(11); text("PRIVATE BELIEF",x+22,y);
    for (int k=0;k<220;k++) {
      stroke(opinionToColor(map(k,0,219,-1,1))); line(x+22+k,y+24,x+22+k,y+30);
    }
    noStroke(); fill(155,164,181); text("-1",x+22,y+38); textAlign(RIGHT,TOP); text("+1",width-38,y+38);
    textAlign(LEFT,TOP); text("Size: followers    Double ring: leader",x+22,y+65);
    text("Arrow: follower > followed",x+22,y+86);
    text("Particle: author > receiver",x+22,y+107);
    text("Positions are visual, not model distances.",x+22,y+128);
  }
  void displayFooter() {
    noStroke(); fill(21,24,32); rect(0,height-38,width-PANEL_WIDTH,38);
    fill(141,154,176); textSize(11); textAlign(LEFT,CENTER);
    int total=player.activeRound > 0 ? data.rounds[player.activeRound].exposures.size() : 0;
    text("SEED "+data.seed+"   |   "+player.label()+"   |   DELIVERED "+player.delivered+" / "+total,22,height-19);
    textAlign(RIGHT,CENTER);
    text(nf(frameRate,0,0)+" FPS   /   "+nf(layout.zoom,0,2)+"x VIEW",width-PANEL_WIDTH-22,height-19);
    float fraction=data.lastRound() == 0 ? 1 : (float)player.completedRound/data.lastRound();
    fill(77,180,191,130); rect(0,height-40,(width-PANEL_WIDTH)*fraction,2);
  }
}

color opinionToColor(float opinion) {
  color negative=color(217,92,137), neutral=color(231,225,214), positive=color(77,180,191);
  float value=constrain(opinion,-1,1);
  return value < 0 ? lerpColor(neutral,negative,-value) : lerpColor(neutral,positive,value);
}
