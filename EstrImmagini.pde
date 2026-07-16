import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.io.IOException;
import java.util.Locale;

PImage img;
boolean showBlueOnly = false;
boolean Test=false;

ArrayList<PVector> calibrationPoints = new ArrayList<PVector>();
boolean calibrated = false;

PVector LaserPoint = new PVector(0,0);
PVector RawPoint=new PVector(0,0);

float meanX = -1;
float meanY = -1;
float mseX = 0;
float mseY = 0;

float laserN=-1;
float laserE=-1;

float scale_x=15; //irl length of calibration lines
float scale_y=25;

float blue_threshold = 2.7;
boolean imageLoaded = false;

String lastImageName = "";

ControlPanel panel; // second window

Table data; //create data table
String data_name="data.csv"; //data savefile name

Table img_points; //create table for image points position
boolean update = false; //updating the img_points value
boolean laser_mode=false; //change mode to laser calibration mode
Table laserData;
String laserDataName = "laser_calib.csv";


// Rectangle selection
boolean selecting = false;
PVector rectStart, rectEnd;

void setup() {
  size(595, 841);
  selectInput("Select an image file:", "fileSelected");

  // Launch second window
  String[] args = {"Control Panel"};
  panel = new ControlPanel();
  PApplet.runSketch(args, panel);
  
  File f  = new File(data_name);
  if (f.exists()){data=loadTable(data_name);}
  else{
    data=new Table();
    data.addColumn("imgName");
    data.addColumn("meanX");
    data.addColumn("meanY");
    data.addColumn("mseX");
    data.addColumn("mseY");
}
File lf = new File(laserDataName);
if (lf.exists()) {
  laserData = loadTable(laserDataName);
} else {
  laserData = new Table();
  laserData.addColumn("imgName");
  laserData.addColumn("E_cm");  // East distance in cm
  laserData.addColumn("N_cm");  // North distance in cm
 
  laserData.addColumn("Ox");  // raw data
  laserData.addColumn("Oy"); 
  laserData.addColumn("Ex");  
  laserData.addColumn("Ey"); 
  laserData.addColumn("Nx");  
  laserData.addColumn("Ny"); 
  laserData.addColumn("Px");  
  laserData.addColumn("Py"); 
}

}

void draw() {
  background(255);

  if (!imageLoaded) {
    fill(0);
    textSize(20);
    textAlign(CENTER, CENTER);
    text("Waiting for image selection...", width / 2, height / 2);
    return;
  }

  image(img, 0, 0);

 if (showBlueOnly && calibrated&&(!laser_mode)) {
  mseX = 0;
  mseY = 0;
  float sumX = 0;
  float sumY = 0;
  int count = 0;

  PVector p0 = calibrationPoints.get(0);
  PVector p1 = calibrationPoints.get(1);
  PVector p2 = calibrationPoints.get(2);

  PVector xAxis = PVector.sub(p1, p0).normalize();
  PVector yAxis = PVector.sub(p2, p0).normalize();

  loadPixels();
  if(update){
  img_points = new Table();
   img_points.addColumn("X");
   img_points.addColumn("Y");}
  for (int i = 0; i < pixels.length; i++) {
    int x = i % width;
    int y = i / width;

    // Restrict to selection box if defined
    if (rectStart != null && rectEnd != null) {
      int minX = int(min(rectStart.x, rectEnd.x));
      int maxX = int(max(rectStart.x, rectEnd.x));
      int minY = int(min(rectStart.y, rectEnd.y));
      int maxY = int(max(rectStart.y, rectEnd.y));
      if (x < minX || x > maxX || y < minY || y > maxY) {
        continue;
      }
    }

    color c = pixels[i];
    if (col_filter(c)) {
      // Transform to calibrated coordinate system
      PVector rel = new PVector(x - p0.x, y - p0.y);
      float xCoord = rel.dot(xAxis)/PVector.sub(p1, p0).mag();
      float yCoord = rel.dot(yAxis)/PVector.sub(p2, p0).mag();

      sumX += xCoord;
      sumY += yCoord;
      count++;
      
       if(update){
         TableRow newRow = img_points.addRow();
         newRow.setFloat("X", xCoord);
         newRow.setFloat("Y", yCoord);
       }
    }

  }
  update=false;  // resets update
  if (count > 1) {
    meanX = sumX / count;
    meanY = sumY / count;

    // Second pass for error
    for (int i = 0; i < pixels.length; i++) {
      int x = i % width;
      int y = i / width;

      // Restrict to selection box if defined
      if (rectStart != null && rectEnd != null) {
        int minX = int(min(rectStart.x, rectEnd.x));
        int maxX = int(max(rectStart.x, rectEnd.x));
        int minY = int(min(rectStart.y, rectEnd.y));
        int maxY = int(max(rectStart.y, rectEnd.y));
        if (x < minX || x > maxX || y < minY || y > maxY) {
          continue;
        }
      }

      color c = pixels[i];
      if (col_filter(c)) {
        PVector rel = new PVector(x - p0.x, y - p0.y);
        float xCoord = rel.dot(xAxis)/PVector.sub(p1, p0).mag();
        float yCoord = rel.dot(yAxis)/PVector.sub(p2, p0).mag();
        mseX += sq(xCoord - meanX);
        mseY += sq(yCoord - meanY);
        pixels[i] = color(50,150,50);
      }
      else {
        pixels[i] = color(0);
      }
    }
  updatePixels();

    mseX = sqrt(mseX / (count-1));
    mseY = sqrt(mseY / (count-1));
  }
  // === Draw crosshair at mean position with error bars ===
if (calibrated) {
  float xLen = PVector.sub(p1, p0).mag();
  float yLen = PVector.sub(p2, p0).mag();

  // Transform mean back into screen coordinates
  PVector meanScreen = PVector.add(
    PVector.add(p0, PVector.mult(xAxis, meanX * xLen)),
    PVector.mult(yAxis, meanY * yLen)
  );

  // Transform error extents into screen space
  PVector errXVec = PVector.mult(xAxis, mseX * xLen);
  PVector errYVec = PVector.mult(yAxis, mseY * yLen);

  // Draw error bars
  stroke(255, 0, 255);  // magenta for error bars
  strokeWeight(2);

  // X error bar
  line(meanScreen.x - errXVec.x, meanScreen.y - errXVec.y,
       meanScreen.x + errXVec.x, meanScreen.y + errXVec.y);

  // Y error bar
  line(meanScreen.x - errYVec.x, meanScreen.y - errYVec.y,
       meanScreen.x + errYVec.x, meanScreen.y + errYVec.y);
}

}

if (calibrated && laser_mode) {
 
  float sumX = 0;
  float sumY = 0;
  int count = 0;

  PVector O = calibrationPoints.get(0); //Or
PVector B = calibrationPoints.get(1).copy().sub(O); //N
PVector A = calibrationPoints.get(2).copy().sub(O);//E

  PVector P = new PVector(0,0);
  RawPoint = new PVector(0,0);

  loadPixels();
  for (int i = 0; i < pixels.length; i++) {
    int x = i % width;
    int y = i / width;

    // Respect selection rectangle if present
    if (rectStart != null && rectEnd != null) {
      int minX = int(min(rectStart.x, rectEnd.x));
      int maxX = int(max(rectStart.x, rectEnd.x));
      int minY = int(min(rectStart.y, rectEnd.y));
      int maxY = int(max(rectStart.y, rectEnd.y));
      if (x < minX || x > maxX || y < minY || y > maxY) continue;
    }

    color c = pixels[i];
    if (col_filter(c)) {
      
      PVector point = new PVector(x, y).sub(O);
      P=P.add(point);
      RawPoint.add(new PVector(x,y));
      count++;
      if (showBlueOnly){
        pixels[i] = color(50,150,50);
      }
    }
    else{
      if(showBlueOnly){pixels[i] = color(0,0,0);}
    }
  }
  updatePixels();
  if (count > 0) {
    P=P.div(count);
    RawPoint.div(count);
    float y_P=scale_x*  (P.dot(A)/A.magSq()-P.dot(B)/A.dot(B))/  (B.dot(A) /A.magSq()-B.magSq()/A.dot(B));
    float x_P=scale_y*(P.dot(A)/A.magSq()  -    (P.dot(A)/A.magSq()-P.dot(B)/A.dot(B))/(pow(B.dot(A),2) /A.magSq()-B.magSq()));
    LaserPoint = new PVector(x_P,y_P);
  }
}


// Always show calibration points as they are being placed
if (imageLoaded && calibrationPoints.size() > 0) {
  stroke(255, 0, 0);
  fill(255, 0, 0);
  for (int i = 0; i < calibrationPoints.size(); i++) {
    PVector p = calibrationPoints.get(i);
    noFill();
    ellipse(p.x, p.y, 10, 10);
    fill(255,0,0);
    textAlign(CENTER, CENTER);
    if (i==0){
      text("Or", p.x, p.y - 15); // label point number
    }
    if (i==1){
      text("N", p.x, p.y - 15); // label point number
    }
    if (i==2){
      text("E", p.x, p.y - 15); // label point number
    }
    fill(255, 0, 0);
  }
}
//show coord. axis
if (calibrationPoints.size() > 1) {
  PVector p0 = calibrationPoints.get(0);
  PVector p1 = calibrationPoints.get(1); 
  
  stroke(0, 0, 155);
  line(p0.x, p0.y, p1.x, p1.y); // X axis
  
  if (calibrated){
  PVector p2 = calibrationPoints.get(2);
  stroke(0, 100, 0);
  line(p0.x, p0.y, p2.x, p2.y);} // Y axis
}

// Draw selection rectangle if active
if (rectStart != null && rectEnd != null) {
  stroke(0, 255, 0);
  noFill();
  rectMode(CORNERS);
  rect(rectStart.x, rectStart.y, rectEnd.x, rectEnd.y);
}

  // Update control panel window values
  if (panel != null) {
    panel.updateStats(meanX, meanY, sqrt(mseX), sqrt(mseY), showBlueOnly, blue_threshold);
  }
}

void fileSelected(File selection) {
  showBlueOnly = false;
  if (selection == null) {
    println("No file selected.");
    return;
  }

  // Save previous stats if available
  if (lastImageName != "" && meanX >= 0 && meanY >= 0) {
    saveStatsCSV(lastImageName, meanX, meanY, mseX, mseY);
  }

  // Load new image
  img = loadImage(selection.getAbsolutePath());
  if (img != null) {
    surface.setSize(img.width, img.height);
    imageLoaded = true;

    // Reset stats
    meanX = -1;
    meanY = -1;
    mseX = 0;
    mseY = 0;

    // Remember this image
    lastImageName = selection.getName();
    //set window name
    frame.setTitle(lastImageName);
  } else {
    println("Failed to load image.");
  }
}
void saveLaserCalib() {
  TableRow row = laserData.addRow();
  row.setString("imgName", lastImageName);
  row.setFloat("E_cm", LaserPoint.x);
  row.setFloat("N_cm", LaserPoint.y);
  
  row.setFloat("Ox", calibrationPoints.get(0).x);
  row.setFloat("Oy", calibrationPoints.get(0).y);
  
  row.setFloat("Nx", calibrationPoints.get(1).x);
  row.setFloat("Ny", calibrationPoints.get(1).y);
  
  row.setFloat("Ex", calibrationPoints.get(2).x);
  row.setFloat("Ey", calibrationPoints.get(2).y);
  
  row.setFloat("Px", RawPoint.x);
  row.setFloat("Py", RawPoint.y);

  saveTable(laserData, laserDataName);
}


void saveStatsCSV(String imgName, float meanX, float meanY, float mseX, float mseY) {
  if(!laser_mode){
  TableRow newRow = data.addRow();
  newRow.setString("imgName", imgName);
  newRow.setFloat("meanX", meanX*scale_x);
  newRow.setFloat("meanY", meanY*scale_y);
  newRow.setFloat("mseX", mseX*scale_x);
  newRow.setFloat("mseY", mseY*scale_y);
  
  saveTable(data, data_name);
  
  saveTable(img_points,  imgName.replaceAll(".jpg|.gif|.png","").concat("_points.csv"));}
  else{
    saveLaserCalib();
  }
}

boolean col_filter (color c){  
  float r = red(c);
  float g = green(c);
  float b = blue(c);
  if(Test){return true;}
  if(!laser_mode){
  return((b/255)<blue_threshold)&&((r/255)*5<blue_threshold)&&((g/255)<blue_threshold)&&(r<(g+b)*0.6);}
  else{
  return(!((g>b)&&(g>r)));}
}

void keyPressed() {
  if (key == 'l' || key == 'L') {
  selectInput("Select an image file:", "fileSelected");
  }
   if (key == 'm' || key == 'M') {
    laser_mode = !laser_mode;
  }
  if (key == 'b' || key == 'B') {
    showBlueOnly = !showBlueOnly;
    update = true;
  }
  if (key == '+') {
    blue_threshold -= 0.05;
    update = true;
  }
  if (key == '-') {
    blue_threshold += 0.05;
    update = true;
  }
  if (key == 'r' || key == 'R') {
    calibrationPoints.clear();
    calibrated = false;
  }
  if(key == 't' || key == 'T'){
    Test=!Test;
  }
  if (key == 's' || key == 'S') {
  if (laser_mode && calibrated) {
    saveLaserCalib();
    println("Laser calibration saved");
  }
}
  if (key == CODED){
  if (calibrationPoints.size() > 0) {
    if (keyCode==UP){
      calibrationPoints.get(calibrationPoints.size()-1).y-=1;
    }
     if (keyCode==DOWN){
      calibrationPoints.get(calibrationPoints.size()-1).y+=1;
    }
    if (keyCode==RIGHT){
      calibrationPoints.get(calibrationPoints.size()-1).x+=1;
    }
    if (keyCode==LEFT){
      calibrationPoints.get(calibrationPoints.size()-1).x-=1;
    }
  }
}
}

void mousePressed() {
  if (!imageLoaded) return;

  if (calibrationPoints.size() < 3) {
    calibrationPoints.add(new PVector(mouseX, mouseY));
    if (calibrationPoints.size() == 3) {
      calibrated = true;
      println("Calibration complete!");
    }
  } else {
    // Start rectangle selection
    selecting = true;
    rectStart = new PVector(mouseX, mouseY);
    rectEnd = rectStart.copy();
  }
}

void mouseDragged() {
  if (selecting) {
    rectEnd.set(mouseX, mouseY);
  }
}

void mouseReleased() {
  if (selecting) {
    rectEnd.set(mouseX, mouseY);
    selecting = false;
    println("Selection box set: (" + rectStart.x + "," + rectStart.y + 
            ") -> (" + rectEnd.x + "," + rectEnd.y + ")");
    update = true; // force recalculation within box
  }
}

// ================== Control Panel Window ==================
public class ControlPanel extends PApplet {
  float meanX, meanY, errX, errY;
  boolean blueOn;
  float threshold;

  public void settings() {
    size(500, 260);
  }

  public void draw() {
    background(240);
    fill(0);
    textSize(14);
    textAlign(LEFT, TOP);
    if (!calibrated){
    text("Calibrate", 20, 20);
    text("Reset calibration with R", 20, 40);
    text("Use arrow keys to move last placed calibration point", 20, 60);
    text("remeber to crop images", 20, 80);}
    else{
      if(!laser_mode){
    text("Mean N: " + nf(meanX*100, 1, 2)+"%; "+ nf(meanX*scale_x, 1, 2)+"cm", 20, 20);
    text("Mean E: " + nf(meanY*100, 1, 2)+"%; "+ nf(meanY*scale_y, 1, 2)+"cm", 20, 40);
    text("Error N: " + nf(errX/meanX*100, 1, 2)+"%; "+ nf(errX*scale_x, 1, 2)+"cm", 20, 60);
    text("Error E: " + nf(errY/meanY*100, 1, 2)+"%; "+ nf(errY*scale_y, 1, 2)+"cm", 20, 80);
    text("Blue Filter: " + (blueOn ? "ON" : "OFF"), 20, 100);
    text("Threshold: " + nf(threshold, 1, 2), 20, 120);}
    else{
      text("Laser E: "+nf(LaserPoint.x)+"cm", 20, 20);
      text("Laser N: "+nf(LaserPoint.y)+"cm", 20, 40);
      text("Press S to save", 30, 70);
    }
    text("Press 'B' to toggle filter and M to change mode", 20, 150);
    text("Press + / - to change threshold", 20, 170);
    text("Reset calibration with R", 20, 190);
    text("Use arrow keys to move last placed calibration point", 20, 210);
    text("Press L to load a new image",20, 230);
  }
  }

  public void updateStats(float mx, float my, float ex, float ey, boolean blue, float t) {
    meanX = mx;
    meanY = my;
    errX = ex;
    errY = ey;
    blueOn = blue;
    threshold = t;
  }
}

@Override
public void exit() {
  // Save stats for the last image if not yet saved
  println(lastImageName);
  println(meanX);
  println(meanY);
  if (lastImageName != "" && meanX >= 0 && meanY >= 0) {
    saveStatsCSV(lastImageName, meanX, meanY, mseX, mseY);
    println("Saved stats for last image before exit.");
  }
  super.exit(); // continue with normal exit
}
