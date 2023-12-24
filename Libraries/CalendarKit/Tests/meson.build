xctest_dep = dependency('XCTest', required: true)

common_objc_args = '-Wno-gnu'
common_dependencies = [xctest_dep]
common_link_with = [calendarkit_lib]
common_include_dirs = include_directories('../')
common_resource_dir = join_paths(meson.current_source_dir(), 'Resources')

# Define the first executable
lineUnfolding = executable(
    'lineUnfolding',
    ['lineUnfolding.m', 'main.m'],
    objc_args: common_objc_args,
    dependencies: common_dependencies,
    link_with: common_link_with,
    include_directories: common_include_dirs
)
test('Line Unfolding Parser Test', lineUnfolding)

# Define the second executable
tokenization = executable(
    'tokenization',
    ['tokenization.m', 'main.m'],
    objc_args: common_objc_args,
    dependencies: common_dependencies,
    link_with: common_link_with,
    include_directories: common_include_dirs
)
test('Tokenization Parser Test', tokenization, args: [common_resource_dir])