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

DEVICE_PATH := device/xiaomi/sm8650

# Inherit from device.mk configuration
$(call inherit-product, $(DEVICE_PATH)/device.mk)

# dependencies (copy only firmware files, skip kernel modules)
PRODUCT_COPY_FILES += $(call find-copy-subdir-files,*,device/xiaomi/sm8650/prebuilts/ruyi/firmware,recovery/root/vendor/firmware)

# Kernel modules for touchscreen and hardware support
# Use minimal set to keep recovery image size small (7.5MB vs 62MB)
# To use all modules, change 'modules_minimal' to 'modules'
PRODUCT_COPY_FILES += $(call find-copy-subdir-files,*,device/xiaomi/sm8650/prebuilts/ruyi/modules_minimal,recovery/root/vendor/lib/modules)

# Release name
PRODUCT_RELEASE_NAME := ruyi

## Device identifier
PRODUCT_DEVICE := sm8650
PRODUCT_NAME := twrp_ruyi
PRODUCT_BRAND := Xiaomi
PRODUCT_MODEL := sm8650
PRODUCT_MANUFACTURER := Xiaomi

