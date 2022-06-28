//
//  VideoParameters.h
//  NativeTasks
//
//  Created by Paul Nettle on 5/13/17.
//
// This file is part of The Nettle Magic Project.
// Copyright © 2022 Paul Nettle. All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file in the root of the source tree.

#if defined(USE_MMAL)

#pragma once

extern "C"
{
   #include "interface/mmal/util/mmal_util_params.h"
}

// Various parameters
// 
//  Exposure Mode
//           MMAL_PARAM_EXPOSUREMODE_OFF,
//           MMAL_PARAM_EXPOSUREMODE_AUTO,
//           MMAL_PARAM_EXPOSUREMODE_NIGHT,
//           MMAL_PARAM_EXPOSUREMODE_NIGHTPREVIEW,
//           MMAL_PARAM_EXPOSUREMODE_BACKLIGHT,
//           MMAL_PARAM_EXPOSUREMODE_SPOTLIGHT,
//           MMAL_PARAM_EXPOSUREMODE_SPORTS,
//           MMAL_PARAM_EXPOSUREMODE_SNOW,
//           MMAL_PARAM_EXPOSUREMODE_BEACH,
//           MMAL_PARAM_EXPOSUREMODE_VERYLONG,
//           MMAL_PARAM_EXPOSUREMODE_FIXEDFPS,
//           MMAL_PARAM_EXPOSUREMODE_ANTISHAKE,
//           MMAL_PARAM_EXPOSUREMODE_FIREWORKS,
// 
//  AWB Mode
//           MMAL_PARAM_AWBMODE_OFF,
//           MMAL_PARAM_AWBMODE_AUTO,
//           MMAL_PARAM_AWBMODE_SUNLIGHT,
//           MMAL_PARAM_AWBMODE_CLOUDY,
//           MMAL_PARAM_AWBMODE_SHADE,
//           MMAL_PARAM_AWBMODE_TUNGSTEN,
//           MMAL_PARAM_AWBMODE_FLUORESCENT,
//           MMAL_PARAM_AWBMODE_INCANDESCENT,
//           MMAL_PARAM_AWBMODE_FLASH,
//           MMAL_PARAM_AWBMODE_HORIZON,
// 
//  Image FX
//           MMAL_PARAM_IMAGEFX_NONE,
//           MMAL_PARAM_IMAGEFX_NEGATIVE,
//           MMAL_PARAM_IMAGEFX_SOLARIZE,
//           MMAL_PARAM_IMAGEFX_POSTERIZE,
//           MMAL_PARAM_IMAGEFX_WHITEBOARD,
//           MMAL_PARAM_IMAGEFX_BLACKBOARD,
//           MMAL_PARAM_IMAGEFX_SKETCH,
//           MMAL_PARAM_IMAGEFX_DENOISE,
//           MMAL_PARAM_IMAGEFX_EMBOSS,
//           MMAL_PARAM_IMAGEFX_OILPAINT,
//           MMAL_PARAM_IMAGEFX_HATCH,
//           MMAL_PARAM_IMAGEFX_GPEN,
//           MMAL_PARAM_IMAGEFX_PASTEL,
//           MMAL_PARAM_IMAGEFX_WATERCOLOUR,
//           MMAL_PARAM_IMAGEFX_FILM,
//           MMAL_PARAM_IMAGEFX_BLUR,
//           MMAL_PARAM_IMAGEFX_SATURATION,
//           MMAL_PARAM_IMAGEFX_COLOURSWAP,
//           MMAL_PARAM_IMAGEFX_WASHEDOUT,
//           MMAL_PARAM_IMAGEFX_POSTERISE,
//           MMAL_PARAM_IMAGEFX_COLOURPOINT,
//           MMAL_PARAM_IMAGEFX_COLOURBALANCE,
//           MMAL_PARAM_IMAGEFX_CARTOON,

class VideoParameters
{
public:
   //
   // Annotate bitmask options
   //

   // Supplied by user on command line
   static const int ANNOTATE_USER_TEXT = 1;

   // Supplied by app using this module
   static const int ANNOTATE_APP_TEXT = 2;

   // Insert current date
   static const int ANNOTATE_DATE_TEXT = 4;

   // Insert current time
   static const int ANNOTATE_TIME_TEXT = 8;

   // Others
   static const int ANNOTATE_SHUTTER_SETTINGS = 16;
   static const int ANNOTATE_CAF_SETTINGS = 32;
   static const int ANNOTATE_GAIN_SETTINGS = 64;
   static const int ANNOTATE_LENS_SETTINGS = 128;
   static const int ANNOTATE_MOTION_SETTINGS = 256;
   static const int ANNOTATE_FRAME_NUMBER = 512;
   static const int ANNOTATE_BLACK_BACKGROUND = 1024;

   // There isn't actually a MMAL structure for the following, so make one
   typedef struct mmal_param_colorfx_s
   {
      int enable;       /// Turn colorFX on or off
      int u,v;          /// U and V to use
   } MMAL_PARAM_COLORFX_T;

   typedef struct param_float_rect_s
   {
      double x;
      double y;
      double w;
      double h;
   } PARAM_FLOAT_RECT_T;

   typedef enum
   {
       ZOOM_IN,
       ZOOM_OUT,
       ZOOM_RESET
   } ZOOM_COMMAND_T;

   /// struct contain camera settings
   int sharpness;             /// -100 to 100
   int contrast;              /// -100 to 100
   int brightness;            ///  0 to 100
   int saturation;            ///  -100 to 100
   int ISO;                   ///  TODO : what range?
   int videoStabilisation;    /// 0 or 1 (false or true)
   int exposureCompensation;  /// -10 to +10 ?
   MMAL_PARAM_EXPOSUREMODE_T exposureMode;
   MMAL_PARAM_EXPOSUREMETERINGMODE_T exposureMeterMode;
   MMAL_PARAM_AWBMODE_T awbMode;
   MMAL_PARAM_IMAGEFX_T imageEffect;
   MMAL_PARAMETER_IMAGEFX_PARAMETERS_T imageEffectsParameters;
   MMAL_PARAM_COLORFX_T colorEffects;
   int rotation;              /// 0-359
   int hflip;                 /// 0 or 1
   int vflip;                 /// 0 or 1
   PARAM_FLOAT_RECT_T  roi;   /// region of interest to use on the sensor. Normalised [0,1] values in the rect
   int shutterSpeed;         /// 0 = auto, otherwise the shutter speed in ms
   float awbGainsRed;         /// AWB red gain
   float awbGainsBlue;         /// AWB blue gain
   MMAL_PARAMETER_DRC_STRENGTH_T drcLevel;  // Strength of Dynamic Range compression to apply
   MMAL_BOOL_T statsPass;    /// Stills capture statistics pass on/off
   int enableAnnotate;       /// Flag to enable the annotate, 0 = disabled, otherwise a bitmask of what needs to be displayed
   char annotateString[MMAL_CAMERA_ANNOTATE_MAX_TEXT_LEN_V2]; /// String to use for annotate - overrides certain bitmask settings
   int annotateTextSize;    // Text size for annotation
   int annotateTextColor;  // Text color for annotation
   int annotateBackgroundColor;    // Background color for annotation
   MMAL_PARAMETER_STEREOSCOPIC_MODE_T stereoMode;

   int checkStatus(MMAL_STATUS_T status);

   void setDefaults();

   int setAllParameters(MMAL_COMPONENT_T *camera);

   // Individual setting functions
   int setSaturation(MMAL_COMPONENT_T *camera, int saturation);
   int setSharpness(MMAL_COMPONENT_T *camera, int sharpness);
   int setContrast(MMAL_COMPONENT_T *camera, int contrast);
   int setBrightness(MMAL_COMPONENT_T *camera, int brightness);
   int setIso(MMAL_COMPONENT_T *camera, int ISO);
   int setMeteringMode(MMAL_COMPONENT_T *camera, MMAL_PARAM_EXPOSUREMETERINGMODE_T mode);
   int setVideoStabilization(MMAL_COMPONENT_T *camera, int vstabilisation);
   int setExposureCompensation(MMAL_COMPONENT_T *camera, int exp_comp);
   int setExposureMode(MMAL_COMPONENT_T *camera, MMAL_PARAM_EXPOSUREMODE_T mode);
   int setAutoWhiteBalanceMode(MMAL_COMPONENT_T *camera, MMAL_PARAM_AWBMODE_T awb_mode);
   int setAutoWhiteBalanceGains(MMAL_COMPONENT_T *camera, float r_gain, float b_gain);
   int setImageEffects(MMAL_COMPONENT_T *camera, MMAL_PARAM_IMAGEFX_T imageFX);
   int setColorEffects(MMAL_COMPONENT_T *camera, const MMAL_PARAM_COLORFX_T *colorFX);
   int setRotation(MMAL_COMPONENT_T *camera, int rotation);
   int setFlips(MMAL_COMPONENT_T *camera, int hflip, int vflip);
   int setRoi(MMAL_COMPONENT_T *camera, PARAM_FLOAT_RECT_T rect);
   int ZoomInOut(MMAL_COMPONENT_T *camera, ZOOM_COMMAND_T zoom_command, PARAM_FLOAT_RECT_T *roi);
   int setShutterSpeed(MMAL_COMPONENT_T *camera, int speed_ms);
   int setDrc(MMAL_COMPONENT_T *camera, MMAL_PARAMETER_DRC_STRENGTH_T strength);
   int setStatsPass(MMAL_COMPONENT_T *camera, int stats_pass);
   int setAnnotate(MMAL_COMPONENT_T *camera, const int bitmask, const char *string, const int text_size, const int text_color, const int bg_color);
   int setStereoMode(MMAL_PORT_T *port, MMAL_PARAMETER_STEREOSCOPIC_MODE_T *stereo_mode);

   void checkConfiguration(int min_gpu_mem);
};

#endif // defined(USE_MMAL)
