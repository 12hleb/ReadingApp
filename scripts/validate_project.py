#!/usr/bin/env python3
"""Offline structural checks. These do NOT compile Swift or run the app's XCTest tests."""
from pathlib import Path
import argparse
import json
import plistlib
import re
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def validate():
    project_path = ROOT / 'SwipeTranslate.xcodeproj/project.pbxproj'
    project = project_path.read_text()
    # The checked-in project uses one OpenStep object per line. Use a separate
    # full OpenStep parser or Xcode when reformatting the project in the future.
    objects = dict(re.findall(r'^\s*([A-F0-9]{24}) = \{ (.*) \};$', project, re.M))
    assert objects, 'Project objects missing'
    references = set(re.findall(r'\b[A-F0-9]{24}\b', project))
    assert references <= objects.keys(), 'Dangling Xcode object reference'
    files = {}
    for identifier, value in objects.items():
        if 'isa = PBXFileReference;' in value and 'sourceTree = SOURCE_ROOT;' in value:
            path = json.loads(re.search(r'path = ("(?:[^"\\]|\\.)*");', value).group(1))
            assert (ROOT / path).exists(), f'Missing file: {path}'
            files[identifier] = path
    source_phases = [value for value in objects.values() if 'isa = PBXSourcesBuildPhase;' in value]
    linked_sources = []
    phase_sources = []
    for phase in source_phases:
        phase_ids = re.findall(r'\b[A-F0-9]{24}\b', phase)
        paths = []
        for build_id in phase_ids:
            reference = re.search(r'fileRef = ([A-F0-9]{24});', objects[build_id]).group(1)
            paths.append(files[reference])
        phase_sources.append(set(paths))
        linked_sources.extend(paths)
    expected = {str(p.relative_to(ROOT)) for p in ROOT.rglob('*.swift')}
    assert set(linked_sources) == expected, 'Unlinked or unexpected Swift source'
    assert len(linked_sources) == len(expected), 'Swift source compiled more than once'
    app_sources = {str(p.relative_to(ROOT)) for p in (ROOT / 'SwipeTranslate').rglob('*.swift')}
    test_sources = {str(p.relative_to(ROOT)) for p in (ROOT / 'SwipeTranslateTests').glob('*.swift')}
    assert app_sources in phase_sources and test_sources in phase_sources, 'App/test target source mix-up'
    scheme = ET.parse(ROOT / 'SwipeTranslate.xcodeproj/xcshareddata/xcschemes/SwipeTranslate.xcscheme')
    for reference in scheme.findall('.//BuildableReference'):
        assert reference.attrib['BlueprintIdentifier'] in objects
    assert scheme.find('.//TestableReference') is not None, 'Test target missing from scheme'
    with (ROOT / 'SwipeTranslate/Resources/Info.plist').open('rb') as handle:
        info = plistlib.load(handle)
    assert info['NSCameraUsageDescription']
    assert info['UISupportedInterfaceOrientations'] == ['UIInterfaceOrientationPortrait']
    assert 'NSAppTransportSecurity' not in info, 'Unexpected transport exception'
    with (ROOT / 'SwipeTranslate/Resources/PrivacyInfo.xcprivacy').open('rb') as handle:
        privacy = plistlib.load(handle)
    assert privacy['NSPrivacyTracking'] is False
    assert privacy['NSPrivacyCollectedDataTypes'] == []
    for path in ROOT.rglob('Contents.json'):
        data = json.loads(path.read_text())
        for item in data.get('images', []):
            if 'filename' in item:
                assert (path.parent / item['filename']).is_file()
    for name, size in [('SwipeTranslate/Resources/Fixtures/sample-page.png', (1400, 1900)),
                       ('SwipeTranslate/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png', (1024, 1024))]:
        data = (ROOT / name).read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n'
        assert struct.unpack('>II', data[16:24]) == size
    test_count = sum(len(re.findall(r'func test\w+\(', (ROOT / p).read_text())) for p in test_sources)
    print(f'PASS: {len(app_sources)} app sources, {len(test_sources)} test files, {test_count} XCTest cases linked.')
    print('PASS: Project references, scheme, resources, privacy manifest, and permission configuration.')
    return expected


def parse_swift(paths):
    try:
        import tree_sitter
        import tree_sitter_swift
    except ImportError:
        raise SystemExit('Optional syntax parser requires: pip install tree-sitter tree-sitter-swift')
    parser = tree_sitter.Parser(tree_sitter.Language(tree_sitter_swift.language()))
    errors = []
    for path in sorted(paths):
        tree = parser.parse((ROOT / path).read_bytes())
        pending = [tree.root_node]
        while pending:
            node = pending.pop()
            if node.type == 'ERROR' or node.is_missing:
                errors.append(f'{path}:{node.start_point.row + 1}: {node.type}')
            pending.extend(node.children)
    assert not errors, '\n'.join(errors)
    print(f'PASS: Swift grammar parse for {len(paths)} source files. Apple API/type checking has NOT run.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--swift-syntax', action='store_true')
    args = parser.parse_args()
    paths = validate()
    if args.swift_syntax:
        parse_swift(paths)
