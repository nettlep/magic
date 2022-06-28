//
//  VideoParameters.cpp
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

#include <stdio.h>
#include <memory.h>
#include <ctype.h>
#include "VideoParameters.h"
#include "Logger.h"
#include "VcosException.h"

extern "C"
{
	#include "interface/vmcs_host/vc_vchi_gencmd.h"
}

/**
 * Convert a MMAL status return value to a simple boolean of success
 * ALso displays a fault if code is not success
 *
 * @param status The error code to convert
 * @return 0 if status is success, 1 otherwise
 */
int VideoParameters::checkStatus(MMAL_STATUS_T status)
{
	if (status == MMAL_SUCCESS) return 0;

	Logger::error(VcosException::statusMessage(status));
	return 1;
}

void VideoParameters::setDefaults()
{
	sharpness = 0;
	contrast = 0;
	brightness = 50;
	saturation = 0;
	ISO = 0; // 0 = auto
	videoStabilisation = 0;
	exposureCompensation = 0;
	exposureMode = MMAL_PARAM_EXPOSUREMODE_AUTO;
	exposureMeterMode = MMAL_PARAM_EXPOSUREMETERINGMODE_AVERAGE;
	awbMode = MMAL_PARAM_AWBMODE_AUTO;
	imageEffect = MMAL_PARAM_IMAGEFX_NONE;
	colorEffects.enable = 0;
	colorEffects.u = 128;
	colorEffects.v = 128;
	rotation = 0;
	hflip = vflip = 0;
	roi.x = roi.y = 0.0;
	roi.w = roi.h = 1.0;
	shutterSpeed = 0; // 0 = auto
	awbGainsRed = 0;   // Only have any function if AWB OFF is used.
	awbGainsBlue = 0;
	drcLevel = MMAL_PARAMETER_DRC_STRENGTH_OFF;
	statsPass = MMAL_FALSE;
	enableAnnotate = 0;
	annotateString[0] = '\0';
	annotateTextSize = 0;    //Use firmware default
	annotateTextColor = -1; //Use firmware default
	annotateBackgroundColor = -1;   //Use firmware default
	stereoMode.mode = MMAL_STEREOSCOPIC_MODE_NONE;
	stereoMode.decimate = MMAL_FALSE;
	stereoMode.swap_eyes = MMAL_FALSE;
}

/**
 * Set the specified camera to all the specified settings
 * @param camera Pointer to camera component
 * @param params Pointer to parameter block containing parameters
 * @return 0 if successful, none-zero if unsuccessful.
 */
int VideoParameters::setAllParameters(MMAL_COMPONENT_T *camera)
{
	int result;

	result = setSaturation(camera, saturation);
	result += setSharpness(camera, sharpness);
	result += setContrast(camera, contrast);
	result += setBrightness(camera, brightness);
	result += setIso(camera, ISO);
	result += setVideoStabilization(camera, videoStabilisation);
	result += setExposureCompensation(camera, exposureCompensation);
	result += setExposureMode(camera, exposureMode);
	result += setMeteringMode(camera, exposureMeterMode);
	result += setAutoWhiteBalanceMode(camera, awbMode);
	result += setAutoWhiteBalanceGains(camera, awbGainsRed, awbGainsBlue);
	result += setImageEffects(camera, imageEffect);
	result += setColorEffects(camera, &colorEffects);
	result += setRotation(camera, rotation);
	result += setFlips(camera, hflip, vflip);
	result += setRoi(camera, roi);
	result += setShutterSpeed(camera, shutterSpeed);
	result += setDrc(camera, drcLevel);
	result += setStatsPass(camera, statsPass);
	result += setAnnotate(camera, enableAnnotate, annotateString,
	                                       annotateTextSize,
	                                       annotateTextColor,
	                                       annotateBackgroundColor);

	return result;
}

/**
 * Adjust the saturation level for images
 * @param camera Pointer to camera component
 * @param saturation Value to adjust, -100 to 100
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setSaturation(MMAL_COMPONENT_T *camera, int saturation)
{
	if (!camera) return 1;
	if (saturation >= -100 && saturation <= 100)
	{
		MMAL_RATIONAL_T value = {saturation, 100};
		return checkStatus(mmal_port_parameter_set_rational(camera->control, MMAL_PARAMETER_SATURATION, value));
	}

	Logger::error("Invalid saturation value");
	return 1;
}

/**
 * Set the sharpness of the image
 * @param camera Pointer to camera component
 * @param sharpness Sharpness adjustment -100 to 100
 */
int VideoParameters::setSharpness(MMAL_COMPONENT_T *camera, int sharpness)
{
	if (!camera) return 1;
	if (sharpness >= -100 && sharpness <= 100)
	{
		MMAL_RATIONAL_T value = {sharpness, 100};
		return checkStatus(mmal_port_parameter_set_rational(camera->control, MMAL_PARAMETER_SHARPNESS, value));
	}
	Logger::error("Invalid sharpness value");
	return 1;
}

/**
 * Set the contrast adjustment for the image
 * @param camera Pointer to camera component
 * @param contrast Contrast adjustment -100 to  100
 * @return
 */
int VideoParameters::setContrast(MMAL_COMPONENT_T *camera, int contrast)
{
	if (!camera) return 1;
	if (contrast >= -100 && contrast <= 100)
	{
		MMAL_RATIONAL_T value = {contrast, 100};
		return checkStatus(mmal_port_parameter_set_rational(camera->control, MMAL_PARAMETER_CONTRAST, value));
	}

	Logger::error("Invalid contrast value");
	return 1;
}

/**
 * Adjust the brightness level for images
 * @param camera Pointer to camera component
 * @param brightness Value to adjust, 0 to 100
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setBrightness(MMAL_COMPONENT_T *camera, int brightness)
{
	if (!camera) return 1;
	if (brightness >= 0 && brightness <= 100)
	{
		MMAL_RATIONAL_T value = {brightness, 100};
		return checkStatus(mmal_port_parameter_set_rational(camera->control, MMAL_PARAMETER_BRIGHTNESS, value));
	}

	Logger::error("Invalid brightness value");
	return 1;
}

/**
 * Adjust the ISO used for images
 * @param camera Pointer to camera component
 * @param ISO Value to set TODO :
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setIso(MMAL_COMPONENT_T *camera, int ISO)
{
	if (!camera) return 1;
	return checkStatus(mmal_port_parameter_set_uint32(camera->control, MMAL_PARAMETER_ISO, ISO));
}

/**
 * Adjust the metering mode for images
 * @param camera Pointer to camera component
 * @param saturation Value from following
 *   - MMAL_PARAM_EXPOSUREMETERINGMODE_AVERAGE,
 *   - MMAL_PARAM_EXPOSUREMETERINGMODE_SPOT,
 *   - MMAL_PARAM_EXPOSUREMETERINGMODE_BACKLIT,
 *   - MMAL_PARAM_EXPOSUREMETERINGMODE_MATRIX
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setMeteringMode(MMAL_COMPONENT_T *camera, MMAL_PARAM_EXPOSUREMETERINGMODE_T m_mode)
{
	if (!camera) return 1;
	MMAL_PARAMETER_EXPOSUREMETERINGMODE_T meter_mode = {{MMAL_PARAMETER_EXP_METERING_MODE, sizeof(meter_mode)}, m_mode};
	return checkStatus(mmal_port_parameter_set(camera->control, &meter_mode.hdr));
}

/**
 * Set the video stabilisation flag. Only used in video mode
 * @param camera Pointer to camera component
 * @param saturation Flag 0 off 1 on
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setVideoStabilization(MMAL_COMPONENT_T *camera, int vstabilisation)
{
	if (!camera) return 1;
	return checkStatus(mmal_port_parameter_set_boolean(camera->control, MMAL_PARAMETER_VIDEO_STABILISATION, vstabilisation));
}

/**
 * Adjust the exposure compensation for images (EV)
 * @param camera Pointer to camera component
 * @param exp_comp Value to adjust, -10 to +10
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setExposureCompensation(MMAL_COMPONENT_T *camera, int exp_comp)
{
	if (!camera) return 1;
	return checkStatus(mmal_port_parameter_set_int32(camera->control, MMAL_PARAMETER_EXPOSURE_COMP, exp_comp));
}

/**
 * Set exposure mode for images
 * @param camera Pointer to camera component
 * @param mode Exposure mode to set from
 *   - MMAL_PARAM_EXPOSUREMODE_OFF,
 *   - MMAL_PARAM_EXPOSUREMODE_AUTO,
 *   - MMAL_PARAM_EXPOSUREMODE_NIGHT,
 *   - MMAL_PARAM_EXPOSUREMODE_NIGHTPREVIEW,
 *   - MMAL_PARAM_EXPOSUREMODE_BACKLIGHT,
 *   - MMAL_PARAM_EXPOSUREMODE_SPOTLIGHT,
 *   - MMAL_PARAM_EXPOSUREMODE_SPORTS,
 *   - MMAL_PARAM_EXPOSUREMODE_SNOW,
 *   - MMAL_PARAM_EXPOSUREMODE_BEACH,
 *   - MMAL_PARAM_EXPOSUREMODE_VERYLONG,
 *   - MMAL_PARAM_EXPOSUREMODE_FIXEDFPS,
 *   - MMAL_PARAM_EXPOSUREMODE_ANTISHAKE,
 *   - MMAL_PARAM_EXPOSUREMODE_FIREWORKS,
 *
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setExposureMode(MMAL_COMPONENT_T *camera, MMAL_PARAM_EXPOSUREMODE_T mode)
{
	if (!camera) return 1;
	MMAL_PARAMETER_EXPOSUREMODE_T exp_mode = {{MMAL_PARAMETER_EXPOSURE_MODE, sizeof(exp_mode)}, mode};
	return checkStatus(mmal_port_parameter_set(camera->control, &exp_mode.hdr));
}

/**
 * Set the aWB (auto white balance) mode for images
 * @param camera Pointer to camera component
 * @param awb_mode Value to set from
 *   - MMAL_PARAM_AWBMODE_OFF,
 *   - MMAL_PARAM_AWBMODE_AUTO,
 *   - MMAL_PARAM_AWBMODE_SUNLIGHT,
 *   - MMAL_PARAM_AWBMODE_CLOUDY,
 *   - MMAL_PARAM_AWBMODE_SHADE,
 *   - MMAL_PARAM_AWBMODE_TUNGSTEN,
 *   - MMAL_PARAM_AWBMODE_FLUORESCENT,
 *   - MMAL_PARAM_AWBMODE_INCANDESCENT,
 *   - MMAL_PARAM_AWBMODE_FLASH,
 *   - MMAL_PARAM_AWBMODE_HORIZON,
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setAutoWhiteBalanceMode(MMAL_COMPONENT_T *camera, MMAL_PARAM_AWBMODE_T awb_mode)
{
	if (!camera) return 1;
	MMAL_PARAMETER_AWBMODE_T param = {{MMAL_PARAMETER_AWB_MODE, sizeof(param)}, awb_mode};
	return checkStatus(mmal_port_parameter_set(camera->control, &param.hdr));
}

int VideoParameters::setAutoWhiteBalanceGains(MMAL_COMPONENT_T *camera, float r_gain, float b_gain)
{
	if (!camera) return 1;
	if (!r_gain || !b_gain) return 0;
	MMAL_PARAMETER_AWB_GAINS_T param = {{MMAL_PARAMETER_CUSTOM_AWB_GAINS, sizeof(param)}, {0, 0}, {0, 0}};
	param.r_gain.num = (unsigned int)(r_gain * 65536);
	param.b_gain.num = (unsigned int)(b_gain * 65536);
	param.r_gain.den = param.b_gain.den = 65536;
	return checkStatus(mmal_port_parameter_set(camera->control, &param.hdr));
}

/**
 * Set the image effect for the images
 * @param camera Pointer to camera component
 * @param imageFX Value from
 *   - MMAL_PARAM_IMAGEFX_NONE,
 *   - MMAL_PARAM_IMAGEFX_NEGATIVE,
 *   - MMAL_PARAM_IMAGEFX_SOLARIZE,
 *   - MMAL_PARAM_IMAGEFX_POSTERIZE,
 *   - MMAL_PARAM_IMAGEFX_WHITEBOARD,
 *   - MMAL_PARAM_IMAGEFX_BLACKBOARD,
 *   - MMAL_PARAM_IMAGEFX_SKETCH,
 *   - MMAL_PARAM_IMAGEFX_DENOISE,
 *   - MMAL_PARAM_IMAGEFX_EMBOSS,
 *   - MMAL_PARAM_IMAGEFX_OILPAINT,
 *   - MMAL_PARAM_IMAGEFX_HATCH,
 *   - MMAL_PARAM_IMAGEFX_GPEN,
 *   - MMAL_PARAM_IMAGEFX_PASTEL,
 *   - MMAL_PARAM_IMAGEFX_WATERCOLOUR,
 *   - MMAL_PARAM_IMAGEFX_FILM,
 *   - MMAL_PARAM_IMAGEFX_BLUR,
 *   - MMAL_PARAM_IMAGEFX_SATURATION,
 *   - MMAL_PARAM_IMAGEFX_COLOURSWAP,
 *   - MMAL_PARAM_IMAGEFX_WASHEDOUT,
 *   - MMAL_PARAM_IMAGEFX_POSTERISE,
 *   - MMAL_PARAM_IMAGEFX_COLOURPOINT,
 *   - MMAL_PARAM_IMAGEFX_COLOURBALANCE,
 *   - MMAL_PARAM_IMAGEFX_CARTOON,
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setImageEffects(MMAL_COMPONENT_T *camera, MMAL_PARAM_IMAGEFX_T imageFX)
{
	if (!camera) return 1;
	MMAL_PARAMETER_IMAGEFX_T imgFX = {{MMAL_PARAMETER_IMAGE_EFFECT, sizeof(imgFX)}, imageFX};
	return checkStatus(mmal_port_parameter_set(camera->control, &imgFX.hdr));
}

/**
 * Set the color effect  for images (Set UV component)
 * @param camera Pointer to camera component
 * @param colorFX  Contains enable state and U and V numbers to set (e.g. 128,128 = Black and white)
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setColorEffects(MMAL_COMPONENT_T *camera, const MMAL_PARAM_COLORFX_T *colorFX)
{
	if (!camera) return 1;
	MMAL_PARAMETER_COLOURFX_T colfx = {{MMAL_PARAMETER_COLOUR_EFFECT, sizeof(colfx)}, 0, 0, 0};
	colfx.enable = colorFX->enable;
	colfx.u = colorFX->u;
	colfx.v = colorFX->v;
	return checkStatus(mmal_port_parameter_set(camera->control, &colfx.hdr));
}

/**
 * Set the rotation of the image
 * @param camera Pointer to camera component
 * @param rotation Degree of rotation (any number, but will be converted to 0,90,180 or 270 only)
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setRotation(MMAL_COMPONENT_T *camera, int rotation)
{
	int my_rotation = ((rotation % 360) / 90) * 90;
	int ret = mmal_port_parameter_set_int32(camera->output[0], MMAL_PARAMETER_ROTATION, my_rotation);
	mmal_port_parameter_set_int32(camera->output[1], MMAL_PARAMETER_ROTATION, my_rotation);
	mmal_port_parameter_set_int32(camera->output[2], MMAL_PARAMETER_ROTATION, my_rotation);
	return ret;
}

/**
 * Set the flips state of the image
 * @param camera Pointer to camera component
 * @param hflip If true, horizontally flip the image
 * @param vflip If true, vertically flip the image
 *
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setFlips(MMAL_COMPONENT_T *camera, int hflip, int vflip)
{
	MMAL_PARAMETER_MIRROR_T mirror = {{MMAL_PARAMETER_MIRROR, sizeof(MMAL_PARAMETER_MIRROR_T)}, MMAL_PARAM_MIRROR_NONE};

	if (hflip && vflip) mirror.value = MMAL_PARAM_MIRROR_BOTH;
	else if (hflip) mirror.value = MMAL_PARAM_MIRROR_HORIZONTAL;
	else if (vflip) mirror.value = MMAL_PARAM_MIRROR_VERTICAL;

	mmal_port_parameter_set(camera->output[0], &mirror.hdr);
	mmal_port_parameter_set(camera->output[1], &mirror.hdr);
	return mmal_port_parameter_set(camera->output[2], &mirror.hdr);
}

/**
 * Set the ROI of the sensor to use for captures/preview
 * @param camera Pointer to camera component
 * @param rect   Normalised coordinates of ROI rectangle
 *
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setRoi(MMAL_COMPONENT_T *camera, PARAM_FLOAT_RECT_T rect)
{
	MMAL_PARAMETER_INPUT_CROP_T crop = {{MMAL_PARAMETER_INPUT_CROP, sizeof(MMAL_PARAMETER_INPUT_CROP_T)}, {0,0,0,0}};

	crop.rect.x = (65536 * rect.x);
	crop.rect.y = (65536 * rect.y);
	crop.rect.width = (65536 * rect.w);
	crop.rect.height = (65536 * rect.h);

	return mmal_port_parameter_set(camera->control, &crop.hdr);
}

/**
 * Adjust the exposure time used for images
 * @param camera Pointer to camera component
 * @param shutter speed in microseconds
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setShutterSpeed(MMAL_COMPONENT_T *camera, int speed)
{
	if (!camera) return 1;
	return checkStatus(mmal_port_parameter_set_uint32(camera->control, MMAL_PARAMETER_SHUTTER_SPEED, speed));
}

/**
 * Adjust the Dynamic range compression level
 * @param camera Pointer to camera component
 * @param strength Strength of DRC to apply
 *        MMAL_PARAMETER_DRC_STRENGTH_OFF
 *        MMAL_PARAMETER_DRC_STRENGTH_LOW
 *        MMAL_PARAMETER_DRC_STRENGTH_MEDIUM
 *        MMAL_PARAMETER_DRC_STRENGTH_HIGH
 *
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setDrc(MMAL_COMPONENT_T *camera, MMAL_PARAMETER_DRC_STRENGTH_T strength)
{
	if (!camera) return 1;
	MMAL_PARAMETER_DRC_T drc = {{MMAL_PARAMETER_DYNAMIC_RANGE_COMPRESSION, sizeof(MMAL_PARAMETER_DRC_T)}, strength};
	return checkStatus(mmal_port_parameter_set(camera->control, &drc.hdr));
}

int VideoParameters::setStatsPass(MMAL_COMPONENT_T *camera, int stats_pass)
{
	if (!camera) return 1;
	return checkStatus(mmal_port_parameter_set_boolean(camera->control, MMAL_PARAMETER_CAPTURE_STATS_PASS, stats_pass));
}

/**
 * Set the annotate data
 * @param camera Pointer to camera component
 * @param Bitmask of required annotation data. 0 for off.
 * @param If set, a pointer to text string to use instead of bitmask, max length 32 characters
 *
 * @return 0 if successful, non-zero if any parameters out of range
 */
int VideoParameters::setAnnotate(MMAL_COMPONENT_T *camera, const int settings, const char *string, const int text_size, const int text_color, const int bg_color)
{
	MMAL_PARAMETER_CAMERA_ANNOTATE_V3_T annotate;
	memset(&annotate, 0, sizeof(annotate));
	annotate.hdr.id = MMAL_PARAMETER_ANNOTATE;
	annotate.hdr.size = sizeof(MMAL_PARAMETER_CAMERA_ANNOTATE_V3_T);
//	MMAL_PARAMETER_CAMERA_ANNOTATE_V3_T annotate = {{MMAL_PARAMETER_ANNOTATE, sizeof(MMAL_PARAMETER_CAMERA_ANNOTATE_V3_T)}};

	if (settings)
	{
		time_t t = time(nullptr);
		struct tm tm = *localtime(&t);
		char tmp[MMAL_CAMERA_ANNOTATE_MAX_TEXT_LEN_V3];
		int process_datetime = 1;

		annotate.enable = 1;

		if (settings & (ANNOTATE_APP_TEXT | ANNOTATE_USER_TEXT))
		{
			if ((settings & (ANNOTATE_TIME_TEXT | ANNOTATE_DATE_TEXT)) && strchr(string, '%') != nullptr)
			{ //string contains strftime parameter?
				strftime(annotate.text, MMAL_CAMERA_ANNOTATE_MAX_TEXT_LEN_V3, string, &tm);
				process_datetime = 0;
			}
			else
			{
				strncpy(annotate.text, string, MMAL_CAMERA_ANNOTATE_MAX_TEXT_LEN_V3);
			}
			annotate.text[MMAL_CAMERA_ANNOTATE_MAX_TEXT_LEN_V3 - 1] = '\0';
		}

		if (process_datetime && (settings & ANNOTATE_TIME_TEXT))
		{
			if (strlen(annotate.text))
			{
				strftime(tmp, 32, " %X", &tm);
			}
			else
			{
				strftime(tmp, 32, "%X", &tm);
			}
			strncat(annotate.text, tmp, MMAL_CAMERA_ANNOTATE_MAX_TEXT_LEN_V3 - strlen(annotate.text) - 1);
		}

		if (process_datetime && (settings & ANNOTATE_DATE_TEXT))
		{
			if (strlen(annotate.text))
			{
				strftime(tmp, 32, " %x", &tm);
			}
			else
			{
				strftime(tmp, 32, "%x", &tm);
			}
			strncat(annotate.text, tmp, MMAL_CAMERA_ANNOTATE_MAX_TEXT_LEN_V3 - strlen(annotate.text) - 1);
		}

		if (settings & ANNOTATE_SHUTTER_SETTINGS) annotate.show_shutter = MMAL_TRUE;
		if (settings & ANNOTATE_GAIN_SETTINGS) annotate.show_analog_gain = MMAL_TRUE;
		if (settings & ANNOTATE_LENS_SETTINGS) annotate.show_lens = MMAL_TRUE;
		if (settings & ANNOTATE_CAF_SETTINGS) annotate.show_caf = MMAL_TRUE;
		if (settings & ANNOTATE_MOTION_SETTINGS) annotate.show_motion = MMAL_TRUE;
		if (settings & ANNOTATE_FRAME_NUMBER) annotate.show_frame_num = MMAL_TRUE;
		if (settings & ANNOTATE_BLACK_BACKGROUND) annotate.enable_text_background = MMAL_TRUE;

		annotate.text_size = text_size;

		if (text_color != -1)
		{
			annotate.custom_text_colour = MMAL_TRUE;
			annotate.custom_text_Y = text_color & 0xff;
			annotate.custom_text_U = (text_color >> 8) & 0xff;
			annotate.custom_text_V = (text_color >> 16) & 0xff;
		}
		else
		{
			annotate.custom_text_colour = MMAL_FALSE;
		}

		if (bg_color != -1)
		{
			annotate.custom_background_colour = MMAL_TRUE;
			annotate.custom_background_Y = bg_color & 0xff;
			annotate.custom_background_U = (bg_color >> 8) & 0xff;
			annotate.custom_background_V = (bg_color >> 16) & 0xff;
		}
		else
		{
			annotate.custom_background_colour = MMAL_FALSE;
		}
	}
	else
	{
		annotate.enable = 0;
	}

	return checkStatus(mmal_port_parameter_set(camera->control, &annotate.hdr));
}

/**
 * Asked GPU how much memory it has allocated
 *
 * @return amount of memory in MB
 */
static int getMemGpu(void)
{
	char response[80] = "";
	int gpu_mem = 0;
	if (vc_gencmd(response, sizeof response, "get_mem gpu") == 0)
	{
		vc_gencmd_number_property(response, "gpu", &gpu_mem);
	}
	return gpu_mem;
}

/**
 * Ask GPU about its camera abilities
 * @param supported None-zero if software supports the camera 
 * @param detected  None-zero if a camera has been detected
 */
static void getCamera(int *supported, int *detected)
{
	char response[80] = "";
	if (vc_gencmd(response, sizeof response, "get_camera") == 0)
	{
		if (supported)
		{
			vc_gencmd_number_property(response, "supported", supported);
		}
		if (detected)
		{
			vc_gencmd_number_property(response, "detected", detected);
		}
	}
}

/**
 * Check to see if camera is supported, and we have allocated enough meooryAsk GPU about its camera abilities
 * @param supported None-zero if software supports the camera 
 * @param detected  None-zero if a camera has been detected
 */
void checkConfiguration(int min_gpu_mem)
{
	int gpu_mem = getMemGpu();
	int supported = 0, detected = 0;
	getCamera(&supported, &detected);
	if (!supported)
		Logger::error("Camera is not enabled in this build. Try running 'sudo raspi-config' and ensure that 'camera' has been enabled");
	else if (gpu_mem < min_gpu_mem)
		Logger::error(SSTR << "Only " << gpu_mem << "M of gpu_mem is configured. Try running 'sudo raspi-config' and ensure that 'memory_split' has a value of " << min_gpu_mem << " or greater");
	else if (!detected)
		Logger::error("Camera is not detected. Please check carefully the camera module is installed correctly");
	else
		Logger::error("Failed to run camera app. Please check for firmware updates");
}

#endif // defined(USE_MMAL)
