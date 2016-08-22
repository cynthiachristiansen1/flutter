// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:path/path.dart' as path;

import '../application_package.dart';
import '../base/logger.dart';
import '../base/utils.dart';
import '../build_info.dart';
import '../globals.dart';
import '../ios/mac.dart';
import 'build.dart';

class BuildIOSCommand extends BuildSubCommand {
  BuildIOSCommand() {
    usesTargetOption();
    addBuildModeFlags();
    argParser.addFlag('simulator', help: 'Build for the iOS simulator instead of the device.');
    argParser.addFlag('codesign', negatable: true, defaultsTo: true,
        help: 'Codesign the application bundle (only available on device builds).');
  }

  @override
  final String name = 'ios';

  @override
  final String description = 'Build an iOS application bundle (Mac OS X host only).';

  @override
  Future<int> runInProject() async {
    await super.runInProject();
    if (getCurrentHostPlatform() != HostPlatform.darwin_x64) {
      printError('Building for iOS is only supported on the Mac.');
      return 1;
    }

    IOSApp app = applicationPackages.getPackageForPlatform(TargetPlatform.ios);

    if (app == null) {
      printError('Application not configured for iOS');
      return 1;
    }

    bool forSimulator = argResults['simulator'];
    bool shouldCodesign = argResults['codesign'];

    if (!forSimulator && !shouldCodesign) {
      printStatus('Warning: Building for device with codesigning disabled. You will '
        'have to manually codesign before deploying to device.');
    }

    if (forSimulator && !isEmulatorBuildMode(getBuildMode())) {
      printError('${toTitleCase(getModeName(getBuildMode()))} mode is not supported for emulators.');
      return 1;
    }

    String logTarget = forSimulator ? 'simulator' : 'device';

    String typeName = path.basename(tools.getEngineArtifactsDirectory(TargetPlatform.ios, getBuildMode()).path);
    Status status = logger.startProgress('Building $app for $logTarget ($typeName)...');
    XcodeBuildResult result = await buildXcodeProject(
      app: app,
      mode: getBuildMode(),
      target: targetFile,
      buildForDevice: !forSimulator,
      codesign: shouldCodesign
    );
    status.stop(showElapsedTime: true);

    if (!result.success) {
      printError('Encountered error while building for $logTarget.');
      return 1;
    }

    if (result.output != null)
      printStatus('Built ${result.output}.');

    return 0;
  }
}
