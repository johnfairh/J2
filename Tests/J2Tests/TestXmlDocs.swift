//
//  TestXmlDocs.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib
import Maaku

class BuilderClient {
    var builder = XMLDocBuilder()
    var doc: CMNode?

    init() {
        doc = nil
        builder.setStartElement() { [weak self] in
            self?.startElement(element: $0, attrs: $1)
        }
    }

    func startElement(element: String, attrs: [String : String]) {
        if element == "Document" {
            XCTAssertNil(doc)
            builder.startDocument() { self.doc = $0 }
        }
    }

    func parse(xml: String) throws {
        try builder.parse(xml: xml)
    }
}


class TestXMLDocs: XCTestCase {

    // MARK: markdown

    func testNotInterested() throws {
        let xml = """
                  <Nothing>
                  Random text
                  <Para>Here is some text.</Para>
                  <Para>Here is some more.</Para>
                  <![CDATA[Random CDATA]]>
                  </Nothing>
                  """

        let client = BuilderClient()
        try client.parse(xml: xml)
        XCTAssertNil(client.doc)
    }

    func testNotXml() throws {
        let xml = "really not xml"
        let client = BuilderClient()
        AssertThrows(try client.parse(xml: xml), J2Error.self)
    }

    func checkDoc(_ xml: String, _ md: String, line: UInt = #line) throws {
        let client = BuilderClient()
        try client.parse(xml: xml)
        XCTAssertNotNil(client.doc)
        XCTAssertEqual(md, client.doc?.renderMarkdown().md, line: line)
    }

    // Nowhere near exhaustive testing of this stuff

    func testText() throws {
        try checkDoc("""
                     <Document>
                     <Para>Para 1.</Para>
                     <Para><bold>bold</bold> <emphasis>italic</emphasis> <codeVoice>codevoice</codeVoice></Para>
                     </Document>
                     """,
                     """
                     Para 1.

                     **bold** *italic* `codevoice`
                     """)
    }

    func testLists() throws {
        try checkDoc("""
                     <Document>
                     <List-Bullet>
                     <Item><Para>Bullet 1</Para></Item>
                     <Item><Para>Bullet 2 Line</Para><Para>Line</Para></Item>
                     <Item><Para>Bullet 3</Para></Item>
                     </List-Bullet>
                     <List-Number>
                     <Item><Para>Line1</Para></Item>
                     <Item><Para>Line2</Para></Item>
                     </List-Number>
                     </Document>
                     """,
                     """
                       - Bullet 1
                       - Bullet 2 Line
                         Line
                       - Bullet 3

                     <!-- end list -->

                     1.  Line1
                     2.  Line2
                     """)
    }

    func testLinks() throws {
        try checkDoc("""
                     <Document>
                     <Para>
                     Before <Link href="http://foo.com">link</Link> after
                     </Para>
                     </Document>
                     """,
                     """
                     Before [link](http://foo.com) after
                     """)

        try checkDoc("""
                     <Document>
                     <Para>
                     <Link>link</Link>
                     </Para>
                     </Document>
                     """,
                     """
                     [link]()
                     """)
    }

    func testCodeListing() throws {
        try checkDoc("""
                     <Document>
                     <CodeListing language="swift">
                     <zCodeLineNumbered><![CDATA[block indent]]></zCodeLineNumbered>
                     <zCodeLineNumbered><![CDATA[  line two]]></zCodeLineNumbered>
                     <zCodeLineNumbered></zCodeLineNumbered>
                     </CodeListing>
                     </Document>
                     """,
                     """
                     ``` swift
                     block indent
                       line two

                     ```
                     """)
    }

    func testBaseRawHtmlEntries() throws {
        try checkDoc("""
                     <Document>
                     <Para>Text<rawHTML><![CDATA[<br/>]]></rawHTML>Text2</Para>
                     <rawHTML><![CDATA[<hr/>]]></rawHTML>
                     </Document>
                     """,
                     """
                     Text  \nText2

                     -----
                     """)

        try checkDoc("""
                     <Document>
                     <Para>Text <![CDATA[<br/>]]></Para>
                     </Document>
                     """,
                     #"""
                     Text \<br/\>
                     """#)
    }

    func testHeadings() throws {
        try checkDoc("""
                     <Document>
                     <rawHTML><![CDATA[<h1>]]></rawHTML>Heading l1<rawHTML><![CDATA[</h1>]]></rawHTML>
                     <Para>Text</Para>
                     <rawHTML><![CDATA[<h2>]]></rawHTML>Head<bold>ing</bold> l2<rawHTML><![CDATA[</h2>]]></rawHTML>
                     </Document>
                     """,
                     """
                     # Heading l1

                     Text

                     ## Head**ing** l2
                     """)
    }

    func testImages() throws {
        try checkDoc(#"""
                     <Document>
                     <Para>
                     <rawHTML><![CDATA[<img src="http://url.com/" title="Hover text" alt="Alt"/>]]></rawHTML>
                     <rawHTML><![CDATA[<img src="http://url.com/" alt="Alt"/>]]></rawHTML>
                     <rawHTML><![CDATA[<img src="http://url.com/"/>]]></rawHTML>
                     <rawHTML><![CDATA[<img src=""/>]]></rawHTML>
                     </Para>
                     </Document>
                     """#,
                     #"""
                     ![Alt](http://url.com/
                     "Hover text")![Alt](http://url.com/)![](http://url.com/)![]()
                     """#)
    }

    func testHTML() throws {
        try checkDoc(#"""
                     <Document>
                     <Para>
                     Text
                     </Para>
                     <rawHTML><![CDATA[<div class="myclass">Boop</div>\#n]]></rawHTML>
                     </Document>
                     """#,
                     #"""
                     Text

                     <div class="myclass">Boop</div>
                     """#)
    }

    // MARK: Declaration

    func testDeclaration() throws {
        let xml = """
                  <CommentParts>
                  <Abstract><Para>Text - Abstract</Para></Abstract>
                  <Parameters>
                  <Parameter><Name>a</Name><Direction isExplicit=\"0\">in</Direction><Discussion><Para>A closure</Para></Discussion></Parameter>
                  <Parameter><Name>f</Name><Direction isExplicit=\"0\">in</Direction><Discussion><Para>A closure param</Para></Discussion></Parameter>
                  </Parameters>
                  <ResultDiscussion><Para>A number</Para></ResultDiscussion>
                  <ThrowsDiscussion><Para>Nothing</Para></ThrowsDiscussion>
                  <Discussion><Para>Text - Discussion</Para>
                  <Invariant><Para>Jim</Para></Invariant>
                  </Discussion>
                  </CommentParts>
                  """
        let declParser = XMLDeclarationBuilder()
        try declParser.parseCommentParts(xml: xml)
        XCTAssertEqual("Text - Abstract", declParser.abstract?.renderPlainText())
        XCTAssertEqual(2, declParser.parameters.count)
        XCTAssertEqual("a", declParser.parameters[0].name.renderPlainText())
        XCTAssertEqual("A closure", declParser.parameters[0].description.renderPlainText())
        XCTAssertEqual("f", declParser.parameters[1].name.renderPlainText())
        XCTAssertEqual("A closure param", declParser.parameters[1].description.renderPlainText())
        XCTAssertEqual("A number", declParser.returns?.renderPlainText())
        XCTAssertEqual("Text - Discussion", declParser.discussion?.renderPlainText())
        XCTAssertEqual(2, declParser.callouts.count)
        XCTAssertEqual("throws", declParser.callouts[0].title)
        XCTAssertEqual("0.  Nothing", declParser.callouts[0].content.renderPlainText())
        XCTAssertEqual("invariant", declParser.callouts[1].title)
        XCTAssertEqual("0.  Jim", declParser.callouts[1].content.renderPlainText())

        // Just sniff the combine part
        let defDocs = declParser.flatDefDocs
        XCTAssertEqual("""
                       Text - Discussion

                         - throws: Nothing

                         - invariant: Jim
                       """,
                       defDocs.discussion?.md)
    }
}
