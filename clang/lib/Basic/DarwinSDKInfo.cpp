//===--- DarwinSDKInfo.cpp - SDK Information parser for darwin - ----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "clang/Basic/DarwinSDKInfo.h"
#include "llvm/Support/ErrorOr.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/Path.h"

using namespace clang;

Optional<VersionTuple> DarwinSDKInfo::RelatedTargetVersionMapping::map(
    const VersionTuple &Key, const VersionTuple &MinimumValue,
    Optional<VersionTuple> MaximumValue) const {
  if (Key < MinimumKeyVersion)
    return MinimumValue;
  if (Key > MaximumKeyVersion)
    return MaximumValue;
  auto KV = Mapping.find(Key.normalize());
  if (KV != Mapping.end())
    return KV->getSecond();
  // If no exact entry found, try just the major key version. Only do so when
  // a minor version number is present, to avoid recursing indefinitely into
  // the major-only check.
  if (Key.getMinor())
    return map(VersionTuple(Key.getMajor()), MinimumValue, MaximumValue);
  // If this a major only key, return None for a missing entry.
  return None;
}

Optional<DarwinSDKInfo::RelatedTargetVersionMapping>
DarwinSDKInfo::RelatedTargetVersionMapping::parseJSON(
    const llvm::json::Object &Obj, VersionTuple MaximumDeploymentTarget) {
  VersionTuple Min = VersionTuple(std::numeric_limits<unsigned>::max());
  VersionTuple Max = VersionTuple(0);
  VersionTuple MinValue = Min;
  llvm::DenseMap<VersionTuple, VersionTuple> Mapping;
  for (const auto &KV : Obj) {
    if (auto Val = KV.getSecond().getAsString()) {
      llvm::VersionTuple KeyVersion;
      llvm::VersionTuple ValueVersion;
      if (KeyVersion.tryParse(KV.getFirst()) || ValueVersion.tryParse(*Val))
        return None;
      Mapping[KeyVersion.normalize()] = ValueVersion;
      if (KeyVersion < Min)
        Min = KeyVersion;
      if (KeyVersion > Max)
        Max = KeyVersion;
      if (ValueVersion < MinValue)
        MinValue = ValueVersion;
    }
  }
  if (Mapping.empty())
    return None;
  return RelatedTargetVersionMapping(
      Min, Max, MinValue, MaximumDeploymentTarget, std::move(Mapping));
}

static Optional<VersionTuple> getVersionKey(const llvm::json::Object &Obj,
                                            StringRef Key) {
  auto Value = Obj.getString(Key);
  if (!Value)
    return None;
  VersionTuple Version;
  if (Version.tryParse(*Value))
    return None;
  return Version;
}

Optional<DarwinSDKInfo>
DarwinSDKInfo::parseDarwinSDKSettingsJSON(const llvm::json::Object *Obj) {
  auto Version = getVersionKey(*Obj, "Version");
  if (!Version)
    return None;
  auto MaximumDeploymentVersion =
      getVersionKey(*Obj, "MaximumDeploymentTarget");
  if (!MaximumDeploymentVersion)
    return None;
  llvm::DenseMap<OSEnvPair::StorageType, Optional<RelatedTargetVersionMapping>>
      VersionMappings;
  if (const auto *VM = Obj->getObject("VersionMap")) {
    if (const auto *Mapping = VM->getObject("macOS_iOSMac")) {
      auto VersionMap = RelatedTargetVersionMapping::parseJSON(
          *Mapping, *MaximumDeploymentVersion);
      if (!VersionMap)
        return None;
      VersionMappings[OSEnvPair::macOStoMacCatalystPair().Value] =
          std::move(VersionMap);
    }
  }

  return DarwinSDKInfo(std::move(*Version),
                       std::move(*MaximumDeploymentVersion),
                       std::move(VersionMappings));
}

Expected<Optional<DarwinSDKInfo>>
clang::parseDarwinSDKInfo(llvm::vfs::FileSystem &VFS, StringRef SDKRootPath) {
  llvm::SmallString<256> Filepath = SDKRootPath;
  llvm::sys::path::append(Filepath, "SDKSettings.json");
  llvm::ErrorOr<std::unique_ptr<llvm::MemoryBuffer>> File =
      VFS.getBufferForFile(Filepath);
  if (!File) {
    // If the file couldn't be read, assume it just doesn't exist.
    return None;
  }
  Expected<llvm::json::Value> Result =
      llvm::json::parse(File.get()->getBuffer());
  if (!Result)
    return Result.takeError();

  if (const auto *Obj = Result->getAsObject()) {
    if (auto SDKInfo = DarwinSDKInfo::parseDarwinSDKSettingsJSON(Obj))
      return std::move(SDKInfo);
  }
  return llvm::make_error<llvm::StringError>("invalid SDKSettings.json",
                                             llvm::inconvertibleErrorCode());
}
