xctest_dep = dependency('XCTest', required: true)

lineUnfolding = executable(
	'lineUnfolding',
	'lineUnfolding.m',
	objc_args: '-Wno-gnu',
	dependencies: [xctest_dep],
	link_with : [calendarkit_lib],
	include_directories: ['../']
)

test('Line Unfolding (Parser) Test', lineUnfolding)