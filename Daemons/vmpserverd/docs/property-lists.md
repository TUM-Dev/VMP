# Property Lists
Property lists are a simple way to encode dictionaries, arrays, strings, numbers, booleans,
and arbitrary data.

The data types closely resemble the classes found in the `Foundation` framework, but are
generally independet of the framework.

Here is a list of the supported data types, and the Foundation class they correspond to. We use
the XML flavour of a serialized property list.
XML-Tag | Foundation Class | Type | Description
--- | --- | --- | ---
`<string>` | NSString | String | A UTF-8 encoded string
`<integer>` or `<real>` | NSNumber | Number | A integer, or floating point number
`<true/>` or `<false/>` | NSNumber | Boolean | A boolean value
`<data>` | NSData | Data | A sequence of bytes (Base64 encoded)
`<array>` | NSArray | Array | An ordered collection of objects
`<dict>` | NSDictionary | Dictionary | An unordered collection of key-value pairs

Here is an example of a property list with the preamble:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>key1</key>
	<string>value1</string>
	<key>key2</key>
	<integer>42</integer>
	<key>key3</key>
	<array>
		<string>value2</string>
		<string>value3</string>
	</array>
</dict>
</plist>
```

A big advantage of property list is the tight integration with the Foundation framework, which
is used throughout the project. Multi-line string support is also available, which is useful
for describing long GStreamer pipelines.
