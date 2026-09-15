class Agent {
  final int id;
  final PVector position;
  final boolean leader;
  final float visualScale, breathPhase;
  Belief belief;
  float opinion, displayedOpinion, targetRadius, displayRadius;
  float arrivalFlash=0, degreePulse=0, degreePulseDirection=0, emissionPulse=0;
  int followerCount=0, following=0;
  boolean selected=false, speaking=false;

  Agent(int id, PVector position, float opinion, boolean leader, float visualScale) {
    this.id=id; this.position=position; this.opinion=opinion; displayedOpinion=opinion;
    this.leader=leader; this.visualScale=visualScale;
    breathPhase=new Random(4700L+id).nextFloat()*TWO_PI;
    displayRadius=targetRadius=radiusForFollowerCount(0);
  }
  void update(float dt) {
    arrivalFlash=max(0,arrivalFlash-dt*1.8);
    degreePulse=max(0,degreePulse-dt*1.25);
    emissionPulse=max(0,emissionPulse-dt*1.7);
    displayedOpinion=lerp(displayedOpinion,opinion,min(1,dt*5.5));
    displayRadius=lerp(displayRadius,targetRadius,min(1,dt*5));
  }
  void display() {
    float diameter=displayRadius*2;
    float breath=0.5+0.5*sin(world.player.visualTime*1.4+breathPhase);
    float unit=visualScale;
    noStroke(); fill(opinionColor(),18+18*breath);
    circle(position.x,position.y,diameter+(5+breath*3)*unit);
    if (degreePulse > 0) {
      float offset=degreePulseDirection > 0 ? 3+(1-degreePulse)*12 : 3+degreePulse*12;
      noFill(); stroke(239,242,247,150*degreePulse); strokeWeight(0.9*unit);
      circle(position.x,position.y,diameter+offset*unit);
    }
    if (arrivalFlash > 0) {
      noFill(); stroke(opinionColor(),185*arrivalFlash); strokeWeight(1.2*unit);
      circle(position.x,position.y,diameter+(4+(1-arrivalFlash)*14)*unit);
    }
    if (leader) {
      noFill(); stroke(224,229,239,160); strokeWeight(0.85*unit);
      circle(position.x,position.y,diameter+5*unit);
      stroke(224,229,239,75);
      circle(position.x,position.y,diameter+(9+breath)*unit);
    }
    if (speaking && emissionPulse > 0) {
      noFill(); stroke(255,175*emissionPulse); strokeWeight(unit);
      circle(position.x,position.y,diameter+(6+(1-emissionPulse)*15)*unit);
    }
    if (selected) {
      noFill(); stroke(255,245); strokeWeight(1.6*unit);
      circle(position.x,position.y,diameter+(leader ? 15 : 9)*unit);
    }
    noStroke(); fill(0,30); circle(position.x+unit,position.y+2*unit,diameter+unit);
    fill(opinionColor()); circle(position.x,position.y,diameter);
    fill(255,28);
    circle(position.x-displayRadius*0.28,position.y-displayRadius*0.30,max(1.5*unit,displayRadius*0.58));
  }
  boolean containsPoint(float x,float y) {
    return dist(x,y,position.x,position.y) <= displayRadius+4*visualScale;
  }
  void beginSpeaking() { speaking=true; emissionPulse=1; }
  void setFollowerCount(int count, boolean animate) {
    int difference=count-followerCount;
    followerCount=count; targetRadius=radiusForFollowerCount(count);
    if (!animate) displayRadius=targetRadius;
    else if (difference != 0) { degreePulseDirection=difference > 0 ? 1 : -1; degreePulse=1; }
  }
  float radiusForFollowerCount(int count) {
    // Fixed area scale throughout a recording; no degree saturation.
    return visualScale*sqrt(3.2*3.2+count*3.4);
  }
  color opinionColor() { return opinionToColor(displayedOpinion); }
}
