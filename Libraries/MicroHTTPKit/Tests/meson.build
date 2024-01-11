

common_objc_args = '-Wno-gnu'
common_dependencies = [xctest_dep]
common_link_with = [microhttpkit_lib]
common_include_dirs = include_directories('../')
common_resource_dir = join_paths(meson.current_source_dir(), 'Resources')

# Define the first executable
routing = executable(
    'routing',
    ['routing.m', 'main.m'],
    objc_args: common_objc_args,
    dependencies: common_dependencies,
    link_with: common_link_with,
    include_directories: common_include_dirs
)
test('Routing Test', routing)
