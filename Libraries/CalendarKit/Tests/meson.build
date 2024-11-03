common_objc_args = '-Wno-gnu'
common_dependencies = [xctest_dep]
common_link_with = [calendarkit_lib]
common_include_dirs = include_directories('../')
common_resource_dir = join_paths(meson.current_source_dir(), 'Resources')

parsing = executable(
    'parsing',
    ['parsing.m', 'main.m'],
    objc_args: common_objc_args,
    dependencies: common_dependencies,
    link_with: common_link_with,
    include_directories: common_include_dirs
)
test('Parsing Test', parsing)

time = executable(
    'time',
    ['time.m', 'main.m'],
    objc_args: common_objc_args,
    dependencies: common_dependencies,
    link_with: common_link_with,
    include_directories: common_include_dirs
)
test('Time Test', time)

equality = executable(
    'equality',
    ['equality.m', 'main.m'],
    objc_args: common_objc_args,
    dependencies: common_dependencies,
    link_with: common_link_with,
    include_directories: common_include_dirs
)
test('Equality Test', equality)