class Layout {
  float zoom = 1, panX = 0, panY = 0;
  float canvasWidth, canvasHeight;
  PVector[] positions;
  Layout(int n, float w, float h) {
    canvasWidth = w; canvasHeight = h;
    positions = new PVector[n];
    Random rng = new Random(4700);
    // Best-candidate placement: evenly dispersed, without a visible grid.
    for (int i = 0; i < n; i++) {
      PVector best = null;
      float bestDistance = -1;
      for (int attempt = 0; attempt < 70; attempt++) {
        PVector p = new PVector(28 + rng.nextFloat()*(w-56), 28 + rng.nextFloat()*(h-56));
        float nearest = Float.MAX_VALUE;
        for (int j = 0; j < i; j++) {
          float dx=p.x-positions[j].x, dy=p.y-positions[j].y;
          nearest = min(nearest, dx*dx+dy*dy);
        }
        if (nearest > bestDistance) { best = p; bestDistance = nearest; }
      }
      positions[i] = best;
    }
  }
  void separate(float[] radii) {
    // Use maximum recorded radii so growth does not continuously relayout nodes.
    for (int pass = 0; pass < 100; pass++) {
      for (int i = 0; i < positions.length; i++) for (int j = 0; j < i; j++) {
        PVector a=positions[i], b=positions[j];
        float dx=a.x-b.x, dy=a.y-b.y, d=sqrt(dx*dx+dy*dy);
        float target=radii[i]+radii[j]+5;
        if (d < target && d > 0.001) {
          float shift=(target-d)*0.26/d;
          a.add(dx*shift,dy*shift); b.sub(dx*shift,dy*shift);
        }
      }
      for (int i = 0; i < positions.length; i++) {
        float margin=radii[i]+12;
        positions[i].x=constrain(positions[i].x,margin,canvasWidth-margin);
        positions[i].y=constrain(positions[i].y,margin,canvasHeight-margin);
      }
    }
  }
  void transform() { translate(panX, 82+panY); scale(zoom); }
  PVector local(float x,float y) { return new PVector((x-panX)/zoom,(y-82-panY)/zoom); }
  void zoomAt(float x,float y,float amount) {
    PVector before=local(x,y);
    zoom=constrain(zoom*pow(1.12,-amount),0.65,5);
    panX=x-before.x*zoom; panY=y-82-before.y*zoom;
  }
  void resetView() { zoom=1; panX=panY=0; }
}
