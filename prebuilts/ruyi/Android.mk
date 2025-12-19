#
# Copyright (C) 2025 The TWRP Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

LOCAL_PATH := $(call my-dir)

# Only build for ruyi device
ifeq ($(TARGET_DEVICE),ruyi)

# Kernel modules for touchscreen and hardware support
KERNEL_MODULES_DIR := modules_minimal

# List of kernel modules
KERNEL_MODULE_NAMES := \
    qcom-spmi-pmic.ko \
    ufs_qcom.ko \
    msm_drm.ko \
    pinctrl-spmi-gpio.ko \
    i2c-msm-geni.ko \
    binder_gki.ko \
    spi-msm-geni.ko \
    goodix_cap.ko

# Declare each kernel module as a prebuilt
$(foreach module,$(KERNEL_MODULE_NAMES), \
    $(eval include $(CLEAR_VARS)) \
    $(eval LOCAL_MODULE := $(basename $(module))) \
    $(eval LOCAL_MODULE_CLASS := ETC) \
    $(eval LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/vendor/lib/modules) \
    $(eval LOCAL_SRC_FILES := $(KERNEL_MODULES_DIR)/$(module)) \
    $(eval LOCAL_MODULE_TAGS := optional) \
    $(eval include $(BUILD_PREBUILT)))

endif # TARGET_DEVICE == ruyi
