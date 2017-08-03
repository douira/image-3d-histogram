//to reduce size (16 million...) color values are divided and floored in order to reduce the color space size
//(file) images must be in one of the formats specified, the images must be named with their id, starting at 0
//set imageAmount to the number of images, not the index of the last image
//images from the internet are loaded in jpg format
//HSB countng mode (activated by setting colorCountingMode to false) is slower than the rgb mode
//change the background color of it interferes with the colors displayed in the histogram
//memory usage is roughly cubic in proportion to colorSpacePoints
//works best when colorSpacePoints is a power of 2 (i.e. 1, 2, 4, 8, 16, 32, 128, 256)
//N: next image (broken)
//I:toggle show image on screen

//--import libraries--
//import peasy cam
import peasy.*;

//--variables--
//data
PImage img; //image to be analysed
color[] imgPixels; //array of colors from the image used to analyse
PeasyCam cam; //cam object for the peasy cam 3d interface
PShape histogram; //PShape (in 3d) to be drawn, created for faster rendering
//variables (changing)
boolean displayImage = true; //is true the image this histogram is made from is displayed on screen, toggled by pressing I
int imageAmount = 0; //counts how many images are available (could be loaded)
float colorAmountMax = 0; //maximum value of the three channels (rgb or hsb depending on setting) used for scaling this channel group histogramm correctly
int currentImageId = 11; //what the id of the image currently displayed is (0 index)
//settings/constants
float displayScaling = 1.3; //scales both displayElementSizeFactor and histogramSizeFactor together
float scrollWheelSensitivity = 0.1; //how much scrolling(=zooming) responds
float displayElementSizeFactor = displayScaling * 6; //scaling of the displayElements
float histogramSizeFactor = displayScaling * 1; //scaling of the whole histogram
int displayElementAlpha = 255; //alpha of the displayElements
color backgroundColor = color(200); //color of the background
int sphereDetailFactor = 2; //sphere segment resolution factor, if smaller sphere, resolution used will be smaller
int[] sphereDetailRange = {6, 30}; //the range of detail the sphere resolution can have
int[] viewRange = {70, 700}; //view range of the peasy cam view (starts of at the center value of these two)
boolean colorCountingMode = true; //if true the image will be processed in rgb mode, if false in hsb
int colorSpacePoints = 256; //(should be below 256) amount of color values per channel reduced to from 256 (wich would result in a VERY big array)
float spaceBetweenPoints = 256 / colorSpacePoints; //sapce between pointsin the reduced color space
int imageGetMode = 0; //get images from 0: from numbered files in folder name provided, 1: from the URL provided, 2: from all images in folder name provided (skins)
String imageGetURL = "https://unsplash.it"; //from what URL (/website) the images are loaded from (must supply the image itself, not on a html page, in one of the formats in the array below
String webImageSearchTerm = "/600/600/?random"; //other parameters used for getting a web image (added to the end of imageGetURL)
String[] imagefileNameSuffixes = {
  "jpg", "png", "tiff", "gif", "tga", "tif", "bmp"
}; //possible file name suffixes of the image to be analysed, id will be added to beginning
int massImageHistogramSuffix = 1; //what suffix all images have when using imageGetMode=2
String imageFolderName = "images/"; //folder name of (/String to append before name of) the images
int imgScaleTo = 300; //to what size small images are scaled to
int imageScalingThreshold = 100; //if image smaller than this it will be scaled until at least imgScaleTo large
boolean verboseLogging = true; //if true additional messages will be printed to console
int maxImageNum = 20; //maximal amount of images to be searched for in images folder
boolean disableDephthWithAlpha = false; //if true and displayElementAlpha is not 255 (there is transparency) then depth testing will be disabled
float sizeScalingExponent = (float)1 / 4; //exponent for size scaling (chnage the extremity of the difference between large and small cubes)
int colorAmountThreshold = 1; //how many times a particular color bucket has to be found to be displayed
int maxBoxAmount = 350000; //maximum allowed amount of boxes to render

//--define utility functions--
//returns the current time stamp nicey formatted
String timeStamp() {
  //return the time with added 0s
  return nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
}

//message function for printing system messages
void msg(int level, String s) {
  //add time
  s = "["+ timeStamp() + "-" + millis() + "ms]" + s; 

  //apply level indicator
  switch (level) {
  case 0: //info-level message
  default:
    //add "INFO"
    s = "INFO" + s;
    break;
  case 1: //warning-level message
    //add "WARNING"
    s = "WARNING" + s;
    break;
  case 2: //error-level message
    //add "ERROR"
    s = "ERROR" + s;
    break;
  case 3: //de-bug message
    //add "DEBUG"
    s = "DEBUG" + s;
    break;
  case 4: //verbose logging message
    //add VERBOSE_LOGGING
    s = "VERBOSE" + s;
    break;
  }

  //print it (if verbose then only if anabled)
  if (level < 4 || verboseLogging) {
    //print
    println(s);
  }
}

//--define specific functions--
//define calcHistogram to count colors of the image and store them in the array and create a shape to be drawn
void calcHistogram() {
  //--init--
  //msg
  msg(0, "Making next histogram from image(s)...");
  
  //stop draw loop to prevent drawing nothingness and error of all sorts
  //noLoop();
  
  //-resetting-
  //reset histogram PShape as group
  histogram = createShape(GROUP);
  
  //main counting array colorAmounts
  float[][][] colorAmounts = new float[colorSpacePoints + 1][colorSpacePoints + 1][colorSpacePoints + 1];
  
  //reset colorAmountMax
  colorAmountMax = 0;

  //--load image--
  //switch to image get mode
  switch (imageGetMode) {
  case 0: //from single file
    //msg
    msg(0, "Loading image with current id from file...");

    //variable for counting in the suffix array
    int currentImageSuffixIndex = -1;

    //reset image to null
    img = null;

    //attempt load image from file
    while (img == null && currentImageSuffixIndex < imagefileNameSuffixes.length) {
      //inrement currentImageSuffixIndex
      currentImageSuffixIndex ++;
      
      //if all suffixes used, increment until at max image number and then reset to 0
      if (currentImageSuffixIndex == imagefileNameSuffixes.length) {
        //if below maxImageNum
        if (currentImageId < maxImageNum) {
          //imcrement image id
          currentImageId ++;
        } //over maxImageNum
        else {
          //reset image id to 0
          currentImageId = 0;
        }
        
        //reset currentImageSuffixIndex to 0
        currentImageSuffixIndex = 0;
      }
      
      //try to load with current suffix
      img = loadImage(imageFolderName + currentImageId + "." + imagefileNameSuffixes[currentImageSuffixIndex]);
    }

    //if image still null
    if (img == null) {
      //print error
      msg(2, "Could not load image, is the given file name correct and is the file a readable image of the type specified?");

      //exit
      exit();
    }
    
    //load pixels in image
    img.loadPixels();
    
    //copy to array
    imgPixels = img.pixels;
  break;
  case 1: //from URL (internet)
    //msg
    msg(0, "Loading image from \"" + imageGetURL + "\"...");

    //get image form random iamge website
    img = loadImage(imageGetURL, "jpg");
    
    //-cut off top 8 and lower 8 pixels rows- (as they contain unreal pixels in form of text)
    //load image pixels
    img.loadPixels();
    
    //set imgPixels array to smaller, cropped version with subset
    imgPixels = (color[])subset(img.pixels, img.width * 8, img.pixels.length - img.width * 8);
  break;
  case 2: //from all files in folder
    //msg
    msg(0, "Loading all images from folder...");
    
    //init imgPixels as empty
    imgPixels = new color[0];
    
    //reset img to null
    img = null;
    
    //reset currentImageId to -1
    currentImageId = -1;
    
    //while still images available (not null)
    do {
      //increment currentImageId
      currentImageId ++;
      
      //load image with current id
      img = loadImage(imageFolderName + currentImageId + "." + imagefileNameSuffixes[massImageHistogramSuffix]);
      
      //if not null
      if (img != null) {
        //load pixels in image
        img.loadPixels();
        
        //append pixels to imgPixels array
        imgPixels = (color[])concat(imgPixels, img.pixels);
      }
    } while (img != null);
    
    //msg finished
    msg(0, "Loaded " + str(currentImageId + 1) + " images with a total of " + imgPixels.length + " pixels.");
  break;
  }
  
  //-scale image (WIP, not satisfying result)-
  //if not on mass image mode
  if (imageGetMode != 2) {
    //if image smaller than  on both sides
    if (img.width < imageScalingThreshold && img.height < imageScalingThreshold) {
      //if width smaller than height
      if (img.width < img.height) {
        //scale height until at least imgScaleTo
        img.resize(0, imgScaleTo);
      } else {//height is smaller
        //scale height until at least imgScaleTo
        img.resize(imgScaleTo, 0);
      }
    }
  }
  
  //msg start of processing
  msg(0, "Processing image pixels...");
  
  //-count colors(histrogram core algorithm)-
  //for each pixel of the image
  for (int i = 0; i < imgPixels.length; i ++) {
    //-get color of this pixel-
    color pixelColor = imgPixels[i];

    //-get color params from image pixel-
    //get alpha value
    float alphaFactor = (pixelColor >> 24) & 0xFF;
    
    //init temp variables for color components
    int v1, v2, v3;
    
    //if rgb or hsb mode
    if (colorCountingMode) { //rgb mode
      //get color values of all three color components: RGB
      v1 = floor(((pixelColor >> 16) & 0xFF) / (256 / colorSpacePoints));
      v2 = floor(((pixelColor >> 8) & 0xFF) / (256 / colorSpacePoints));
      v3 = floor((pixelColor & 0xFF) / (256 / colorSpacePoints));
    } else { //hsb mode (slower)
      //get color values of all three color components: HSB
      v1 = floor(hue(pixelColor) / (256 / colorSpacePoints));
      v2 = floor(saturation(pixelColor) / (256 / colorSpacePoints));
      v3 = floor(brightness(pixelColor) / (256 / colorSpacePoints));
    }
    
    //-increment at right position for index of properties in this pixel and scale with alpha-
    colorAmounts[v1][v2][v3] += alphaFactor / 255;
    
    //-get max value-
    colorAmountMax = max(colorAmountMax, colorAmounts[v1][v2][v3]);
  }
  
  msg(0, "optimizing render data");
  //reset to default of 1
  colorAmountThreshold = 1;
  
  //until not more than maxBoxAmount buckets are at threshold amount
  int toBeRenderedAmount;
  do {
    toBeRenderedAmount = 0;
    for (int x = 0; x < colorAmounts.length; x ++) {
      for (int y = 0; y < colorAmounts[0].length; y ++) {
        for (int z = 0; z < colorAmounts[0][0].length; z ++) {
          if (colorAmounts[x][y][z] >= colorAmountThreshold) {
            toBeRenderedAmount ++;
          }
        }
      }
    }
    //if still above max
    if (toBeRenderedAmount > maxBoxAmount) {
      colorAmountThreshold ++;
    } else {
      break;
    }
  } while (true);
  msg(4, "Rendering " + toBeRenderedAmount + " boxes and got to bucket count treshold " + colorAmountThreshold);
  
  //--create a PShape for faster rendering--
  msg(0, "generating shape for rendering");
  //for every space (counter) colorAmounts
  for (int x = 0; x < colorAmounts.length; x ++) {
    for (int y = 0; y < colorAmounts[0].length; y ++) {
      for (int z = 0; z < colorAmounts[0][0].length; z ++) {
        //stop if not there
        if (colorAmounts[x][y][z] < colorAmountThreshold) {
          continue;
        }
        
        //calculate displayElement size
        float displayElementSize = pow(colorAmounts[x][y][z] / colorAmountMax, sizeScalingExponent) * displayElementSizeFactor;
        
        //scale to calculated size
        //displayElement.scale(displayElementSize);
        
        //create child PShape
        PShape displayElement = createShape(BOX, displayElementSize);
        
        //begin child shape making
        //displayElement.beginShape();
        
        //translate to position
        displayElement.translate(x * spaceBetweenPoints, y * spaceBetweenPoints, z * spaceBetweenPoints);
        
        //remove stroke
        displayElement.setStroke(false);
        
        //set fill to color in that position
        //if hsb mode
        if (! colorCountingMode) {
           //set shape to hsb color mode
          colorMode(HSB);
        }
        
        //set fill
        displayElement.setFill(color(x * spaceBetweenPoints, y * spaceBetweenPoints, z * spaceBetweenPoints, displayElementAlpha));
        
        //set sphere detail with sphereDetailFactor and constrain to specified values
        //displayElementElement.sphereDetail(constrain(sphereDetailFactor * floor(displayElementSize), sphereDetailRange[0], sphereDetailRange[1]));

        //make a cube with displayElementSize as radius to center of faces
        // +Z "front" face
        /*displayElement.vertex(-1, -1,  1);
        displayElement.vertex( 1, -1,  1);
        displayElement.vertex( 1,  1,  1);
        displayElement.vertex(-1,  1,  1);
      
        // -Z "back" face
        displayElement.vertex( 1, -1, -1);
        displayElement.vertex(-1, -1, -1);
        displayElement.vertex(-1,  1, -1);
        displayElement.vertex( 1,  1, -1);
      
        // +Y "bottom" face
        displayElement.vertex(-1,  1,  1);
        displayElement.vertex( 1,  1,  1);
        displayElement.vertex( 1,  1, -1);
        displayElement.vertex(-1,  1, -1);
      
        // -Y "top" face
        displayElement.vertex(-1, -1, -1);
        displayElement.vertex( 1, -1, -1);
        displayElement.vertex( 1, -1,  1);
        displayElement.vertex(-1, -1,  1);
      
        // +X "right" face
        displayElement.vertex( 1, -1,  1);
        displayElement.vertex( 1, -1, -1);
        displayElement.vertex( 1,  1, -1);
        displayElement.vertex( 1,  1,  1);
      
        // -X "left" face
        displayElement.vertex(-1,  1, -1);
        displayElement.vertex(-1,  1,  1);
        displayElement.vertex(-1, -1,  1);
        displayElement.vertex(-1, -1, -1);*/
        
        //end child shape making
        //displayElement.endShape();
        
        //add shape to main histogram shape
        histogram.addChild(displayElement);
      }
    }
  }
  
  //translate to centered position
  histogram.translate(-128, -128, -128);
  
  //scale histrogram
  histogram.scale(histogramSizeFactor);
  
  //--done, start to draw--
  //msg draw
  msg(0, "Starting to draw histogram...");
  
  //re-enable draw loop
  //loop();
}

//--setup function--
void setup() {
  //set size to fullscreen size with P3D for 3d rendering
  fullScreen(P3D);

  //msg
  msg(0, "Startup...");
  
  //init peasy cam with center of 
  cam = new PeasyCam(this, (viewRange[0] + viewRange[1]) / 2);
  
  //set max and min view range params
  cam.setMinimumDistance(viewRange[0]);
  cam.setMaximumDistance(viewRange[1]);
  
  //set scroll wheel sensitivity
  cam.setWheelScale(scrollWheelSensitivity);
  
  //append webImageSearchTerm to imageGetURL
  imageGetURL += webImageSearchTerm;
  
  //decrement colorSpacePoints by 1
  //colorSpacePoints --;
  
  //-calculate histogram for first image-
  calcHistogram();
}

//--draw function to keep sketch running--
void draw() {
  //-draw background with specified color-
  background(backgroundColor);
  
  //display image or histogram, if image displaying is enabled
  if (displayImage) {
    //-display image-
    //start HUD drawing
    cam.beginHUD();
    
    //draw image
    image(img, 0, 0);
    
    //end HUD drawing
    cam.endHUD();
  }
  
  //-draw histogram PShape-
  histogram.setVisible(true);
  shape(histogram);
  
  //-draw bounding cube-
  //remove fill
  noFill();
  
  //set stroke to black
  stroke(0);
  
  //draw box
  box(histogramSizeFactor * 256);
}

//--define callback functions--
//define keyTyped to get key presses for user interaction
void keyTyped() {
  //switch to key pressed
  /*if (str(key).equals("n")) { //N for next image
    //if single image from file
    if (imageGetMode == 0) {
      //increment image id and wrap if at end of image range
      currentImageId ++;
    }
    
    //-recalc histogram-
    calcHistogram();
  }
  else*/ if (str(key).equals("i") && imageGetMode != 2) { //I for toggle display image and if not on mass image mode (imageGetMode = 2)
    //invert displayImage to toggle
    displayImage = ! displayImage;
  }
}