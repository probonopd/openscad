#!/bin/bash

if [[ "$BUILD" == "appimage" ]] ; then 
  set -x
  # Scintilla is not found, as usual :-(
  # https://github.com/openscad/openscad/blob/master/scintilla.pri#L13
  # How am I supposed to know what OPENSCAD_LIBDIR is?
  # The following paths exist:
  # /usr/share/qt5/mkspecs/features/qscintilla2.prf
  # Taking a wild guess here:
  find /usr -name qscintilla2.prf -exec cp {} . \; # https://github.com/openscad/openscad/issues/981#issuecomment-176820343
  sudo cp /usr/share/qt5/mkspecs/features/qscintilla2.prf /opt/qt*/mkspecs/linux-g++/features/
  sudo ln -s /usr/include/qt5/Qsci /usr/include/x86_64-linux-gnu/qt5/ # https://github.com/openscad/openscad/pull/1778#issuecomment-321368294
  # Still getting:
  # src/scadlexer.h:5:29: fatal error: Qsci/qsciglobal.h: No such file or directory
  qmake PREFIX=/usr
  make -j$(nproc)
  make INSTALL_ROOT=appdir install ; find appdir/
  wget -c "https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage" 
  chmod a+x linuxdeployqt*.AppImage
  unset QTDIR; unset QT_PLUGIN_PATH ; unset LD_LIBRARY_PATH
  ./linuxdeployqt*.AppImage ./appdir/usr/share/applications/*.desktop -bundle-non-qt-libs
  ./linuxdeployqt*.AppImage ./appdir/usr/share/applications/*.desktop -appimage
  find ./appdir -executable -type f -exec ldd {} \; | grep " => /usr" | cut -d " " -f 2-3 | sort | uniq
  curl --upload-file ./APPNAME*.AppImage https://transfer.sh/APPNAME-git.$(git rev-parse --short HEAD)-x86_64.AppImage
  exit $?
fi

qmake CONFIG+=experimental CONFIG+=nogui
make

cd tests
cmake . 
if [[ $? != 0 ]]; then
  echo "Error configuring test suite"
  exit 1
fi
make -j2
if [[ $? != 0 ]]; then
  echo "Error building test suite"
  exit 1
fi

if [[ "$DIST" == "trusty" ]]; then
    PARALLEL=-j1
else
    PARALLEL=-j8
fi

# Exclude tests known the cause issues on Travis
# opencsgtest_rotate_extrude-tests - Fails on Ubuntu 12.04 using Gallium 0.4 drivers
# *_text-font-direction-tests - Fails due to old freetype (issue #899)
# throwntogethertest_issue964 - Fails due to non-planar quad being tessellated slightly different
# opencsgtest_issue1165 - z buffer tearing

# Fails on Apple's software renderer:
# opencsgtest_issue1258
# throwntogethertest_issue1089
# throwntogethertest_issue1215
ctest $PARALLEL -E "\
opencsgtest_rotate_extrude-tests|\
opencsgtest_render-tests|\
opencsgtest_rotate_extrude-hole|\
opencsgtest_internal-cavity|\
opencsgtest_internal-cavity-polyhedron|\
opencsgtest_minkowski3-erosion|\
opencsgtest_issue835|\
opencsgtest_issue911|\
opencsgtest_issue913|\
opencsgtest_issue1215|\
opencsgtest_issue1105d|\
dxfpngtest_text-font-direction-tests|\
cgalpngtest_text-font-direction-tests|\
opencsgtest_text-font-direction-tests|\
csgpngtest_text-font-direction-tests|\
svgpngtest_text-font-direction-tests|\
throwntogethertest_text-font-direction-tests|\
throwntogethertest_issue964|\
opencsgtest_issue1165|\
opencsgtest_issue1258|\
throwntogethertest_issue1089|\
throwntogethertest_issue1215\
"
if [[ $? != 0 ]]; then
  echo "Test failure"
  exit 1
fi
