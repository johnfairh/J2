//
//  MustacheGen.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// Gubbins to generate a sequence of `MustachePage`s from a `GenData`.
/// This loops over all the pages for every language being produced.
extension GenData {
    public struct Iterator: IteratorProtocol {
        let genData: GenData
        let fileExt: String
        var locIterator: Array<String>.Iterator
        var nextPage: Int
        var currentLanguageTag: String

        init(genData: GenData, fileExt: String) {
            self.genData = genData
            self.fileExt = fileExt
            self.locIterator = Localizations.shared.allTags.makeIterator()
            self.nextPage = 0
            self.currentLanguageTag = locIterator.next()!
        }

        public mutating func next() -> MustachePage? {
            if nextPage == genData.pages.count {
                // done all the pages of the current language
                guard let nextLanguageTag = locIterator.next() else {
                    // No more languages: the end
                    return nil
                }
                currentLanguageTag = nextLanguageTag
                nextPage = 0
            }
            defer { nextPage += 1 }
            return genData.generate(page: nextPage,
                                    languageTag: currentLanguageTag,
                                    fileExt: fileExt)
        }
    }

    public func makeIterator(fileExt: String) -> Iterator {
        Iterator(genData: self, fileExt: fileExt)
    }
}

// MARK: Generate

/// The type fed to the mustache templates to generate a page
public struct MustachePage {
    let languageTag: String
    let filepath: String
    let data: [String : Any]
}

extension Dictionary where Key == String {
    subscript(arg: MustacheKey) -> Value? {
        set { self[arg.rawValue] = newValue }
        get { self[arg.rawValue] }
    }
}

public enum MustacheKey: String {
    // Global, fixed
    case j2libVersion = "j2lib_version"
    case hideSearch = "disable_search"
    case hideAttribution = "hide_attribution"
    case hideAvailability = "hide_availability"
    case hideActions = "hide_actions"
    case docCoverage = "doc_coverage"
    case customHead = "custom_head"
    case itemCollapseOpen = "item_collapse_open"
    case itemCollapseNever = "item_collapse_never"
    case itemNest = "item_nest"
    case dualLanguage = "dual_language"
    case defaultLanguage = "default_language"

    // Global, per-page
    case languageTag = "language_tag"
    case primaryPageTitle = "primary_page_title"
    case primaryTitleLanguage = "primary_title_language"
    case secondaryPageTitle = "secondary_page_title"
    case secondaryTitleLanguage = "secondary_title_language"
    case tabTitlePrefix = "tab_title_prefix"
    case pathToRoot = "path_to_root" // empty string or ends in "/"
    case tocs = "tocs"
    case toc = "toc"
    case hideArticleTitle = "hide_article_title"
    case contentHtml = "content_html"
    case apologyLanguage = "apology_language"
    case noApologyLanguage = "no_apology_language"
    case apology = "apology"
    // Global, set by SiteGen
    case pathToAssets = "path_to_assets" // empty string or ends in "/"
    case docsTitle = "docs_title"
    case breadcrumbsRoot = "breadcrumbs_root"
    case copyrightHtml = "copyright_html"
    // Localizations menu -- only set if there are multiple localizations
    case pageLocalization = "page_localization"
    case localizations = "localizations"
    case active = "active"
    // Breadcrumbs
    case breadcrumbsMenus = "breadcrumbs_menus"
    case breadcrumbs = "breadcrumbs"

    // Definitions
    case def = "def"
    case deprecationHtml = "deprecation_html"
    case availability = "availability"
    case abstractHtml = "abstract_html"
    case overviewHtml = "overview_html"
    case swiftDeclarationHtml = "swift_declaration_html"
    case objCDeclarationHtml = "objc_declaration_html"
    case parameters = "parameters"
    case parameterHtml = "parameter_html"
    case returnsHtml = "returns_html"

    // Topics
    case topics = "topics"
    case topicsLanguage = "topics_language"
    case titleHtml = "title_html"
    case anchorId = "anchor_id"
    case dashName = "dash_name"

    // Topics menu
    case topicsMenus = "topics_menus"
    case topicsMenu = "topics_menu"
    case language = "language"

    // Items
    case items = "items"
    case dashType = "dash_type"
    case primaryTitleHtml = "primary_title_html"
    case secondaryTitleHtml = "secondary_title_html"
    case primaryLanguage = "primary_language"
    case secondaryLanguage = "secondary_language"
    case anyDeclaration = "any_declaration"
    case primaryUrl = "primary_url"
    case secondaryUrl = "secondary_url"

    // ToC entries
    case title = "title"
    case url = "url"
    case samePage = "same_page"
    case children = "children"
    case screenReaderName = "screen_reader_name"

    static func dict(_ pairs: KeyValuePairs<MustacheKey, Any>) -> [String : Any] {
        Dictionary(uniqueKeysWithValues: pairs.map { ($0.0.rawValue, $0.1) })
    }
}

private func MH(_ pairs: KeyValuePairs<MustacheKey, Any>) -> [String : Any] {
    MustacheKey.dict(pairs)
}

private extension Dictionary where Key == String, Value == Any {
    mutating func maybe(_ k: MustacheKey, _ v: Any?) {
        if let v = v {
            self[k.rawValue] = v
        }
    }
}

extension DefLanguage {
    var apologyMessage: Localized<String> {
        switch self {
        case .swift: return .localizedOutput(.notSwift)
        case .objc: return .localizedOutput(.notObjc)
        }
    }
}

extension GenData {
    public func generate(page: Int, languageTag: String, fileExt: String) -> MustachePage {
        var data = [String: Any]()
        let pg = pages[page]
        let filepath = pg.url.filepath(fileExtension: fileExt)
        data[.languageTag] = languageTag
        data[.primaryPageTitle] = pg.primaryTitle[languageTag]
        data[.primaryTitleLanguage] = pg.primaryLanguage.cssName
        if let secondaryTitle = pg.secondaryTitle {
            data[.secondaryPageTitle] = secondaryTitle[languageTag]
            data[.secondaryTitleLanguage] = pg.primaryLanguage.otherLanguage.cssName
        }
        data[.tabTitlePrefix] = pg.tabTitlePrefix
        data[.pathToRoot] = pg.url.pathToRoot
        data[.hideArticleTitle] = pg.isGuide
        data.maybe(.contentHtml, pg.content?.get(languageTag).html)
        data.maybe(.def, pg.def?.generateDef(languageTag: languageTag, fileExt: fileExt))

        data[.breadcrumbsMenus] = zip(meta.languages, pg.breadcrumbs).map { breadcrumbSrc in
            MH([.breadcrumbs: breadcrumbSrc.1.map { bc -> [String:Any] in
                                  var dict = MH([.title: bc.title.get(languageTag)])
                                  dict.maybe(.url, bc.url?.url(fileExtension: fileExt, language: breadcrumbSrc.0))
                                  return dict
                              },
                .language: breadcrumbSrc.0.cssName])
        }

        let topics = pg.generateTopics(languageTag: languageTag, fileExt: fileExt)
        let soloTopicsLanguage = pg.soloTopicsLanguage
        data.maybe(.topicsLanguage, soloTopicsLanguage?.cssName)
        if let apology = generateApology(page: pg, soloTopicsLanguage: soloTopicsLanguage) {
            data[.apologyLanguage] = apology.0.cssName
            data[.noApologyLanguage] = apology.0.otherLanguage.cssName
            data[.apology] = apology.1.get(languageTag)
        }
        data[.topics] = topics
        data[.topicsMenus] = meta.languages.compactMap { lang -> [String:Any]? in
            let topicsMenu = pg.generateTopicsMenu(language: lang,
                                                   languageTag: languageTag)
            guard !topicsMenu.isEmpty else {
                return nil
            }

            return MH([.topicsMenu: topicsMenu,
                       .language: lang.cssName])
        }

        data[.tocs] = zip(meta.languages, tocs).map { tocSrc in
            MH([.toc: generateToc(from: tocSrc.1,
                                  language: tocSrc.0,
                                  languageTag: languageTag,
                                  fileExt: fileExt,
                                  pageURLPath: pg.url.url(fileExtension: fileExt)),
                .language: tocSrc.0.cssName,
                .screenReaderName: tocSrc.0.screenReaderName])
        }

        return MustachePage(languageTag: languageTag, filepath: filepath, data: data)
    }

    /// Figure out when we need to invent some text for a language that the docset supports but the page doesn't.
    func generateApology(page: Page, soloTopicsLanguage: DefLanguage?) -> (DefLanguage, Localized<String>)? {
        guard meta.languages.count == 2, !page.isGuide else {
            return nil
        }
        let apologyLanguage: DefLanguage
        if let def = page.def {
            // definition
            if def.swiftDeclaration == nil && def.objCDeclaration != nil {
                apologyLanguage = .swift
            } else if def.swiftDeclaration != nil && def.objCDeclaration == nil {
                apologyLanguage = .objc
            } else {
                return nil
            }
        } else if let soloTopicsLanguage = soloTopicsLanguage {
            // group, all contents in one language
            apologyLanguage = soloTopicsLanguage.otherLanguage
        } else {
            // group, mixed topics
            return nil
        }
        return (apologyLanguage, apologyLanguage.apologyMessage)
    }

    /// Generate the table of contents (left nav) for the page.
    /// This is unique for each page because the URLs change around the current page, and translation.
    /// keys:
    ///   language: css-class for the toc
    ///   title: text for the entry
    ///   children: option array of this same format
    ///   url: optional href to the entry [not set if we're already there]
    ///   same_page: true if 'url' is a #href on the same page we're on
    func generateToc(from toc: [TocEntry],
                     language: DefLanguage,
                     languageTag: String,
                     fileExt: String,
                     pageURLPath: String) -> [[String : Any]] {

        func tocList(entries: [TocEntry]) -> [[String : Any]] {
            entries.map { entry in
                let entryURLPath = entry.url.url(fileExtension: fileExt, language: language)
                var dict = MH([.title: entry.title.get(languageTag)])
                let children = tocList(entries: entry.children)
                if !children.isEmpty {
                    dict[.children] = children
                }
                if entryURLPath != pageURLPath {
                    // no url for the page we're currently on.
                    if entryURLPath.hasPrefix(pageURLPath) {
                        // #link to something on the same page
                        dict[.url] = entry.url.hashURL
                        dict[.samePage] = true
                    } else {
                        dict[.url] = entryURLPath
                        dict[.samePage] = false
                    }
                }
                return dict
            }
        }

        return tocList(entries: toc)
    }
}

extension GenData.Page {
    /// topics is an array of [String : Any]
    func generateTopics(languageTag: String, fileExt: String) -> [[String : Any]] {
        topics.map { $0.generateTopic(languageTag: languageTag, fileExt: fileExt) }
    }

    /// topics_menu is array of [String:Any]
    /// keys:  title - plain text title of topic
    ///      anchor_id - href without leading hash of topic on page
    ///
    /// There's one topics menu for each language on the page.
    /// Include a 'Declaration' item for the main item if present.
    func generateTopicsMenu(language: DefLanguage,
                            languageTag: String) -> [[String: Any]] {
        var topicsMenu = [[String: Any]]()
        if def != nil {
            let declaration = Localized<String>.localizedOutput(.declaration).get(languageTag)
            topicsMenu.append(MH([.title: declaration, .anchorId: ""]))
        }
        return topicsMenu +
            topics.compactMap { $0.generateMenuItem(language: language, languageTag: languageTag) }
    }

    /// Identify if all topics are dependent on one language
    var soloTopicsLanguage: DefLanguage? {
        var theLanguage: DefLanguage? = nil
        for topic in topics {
            guard let topicSoloLanguage = topic.soloLanguage else {
                return nil // bilingual topic
            }
            if theLanguage == nil {
                theLanguage = topicSoloLanguage // first lang
            } else if theLanguage != topicSoloLanguage {
                return nil // diff solo lang
            }
        }
        return theLanguage
    }
}

extension GenData.Topic {
    /// Identify if every item in this topic is only present in the same one language.
    /// If so then cascade that behaviour into the topic itself.
    var soloLanguage: DefLanguage? {
        var theLanguage: DefLanguage? = nil
        for item in items {
            if item.secondaryLanguage != nil || // bilingual
                item.primaryTitleHtml == nil {  // direct-link
                return nil
            }
            if theLanguage == nil {
                theLanguage = item.primaryLanguage // first match
            } else if theLanguage != item.primaryLanguage {
                return nil // different 1-language
            }
        }
        return theLanguage
    }

    /// topics is an array of [String : Any]
    /// with keys title_html [can be missing if 0 title]
    ///           overview_html [can be missing]
    ///           anchor_id -- need for linking from aux nav
    ///           dash_name - %-encoded text (markdown) name
    ///           primary_language - if set then topic is only valid in that language
    ///           items - items array of [String: Any]
    func generateTopic(languageTag: String, fileExt: String) -> [String : Any] {
        let titleText = title.markdown.get(languageTag).md
        let dashName = titleText.urlPathEncoded
        var dict = MH([.anchorId: anchorId, .dashName: dashName])
        if !titleText.isEmpty {
            dict[.titleHtml] = title.html.get(languageTag).html
        }
        dict.maybe(.overviewHtml, body?.get(languageTag).html)
        dict.maybe(.primaryLanguage, soloLanguage?.cssName)
        if items.count > 0 {
            dict[.items] = items.map {
                $0.generateItem(languageTag: languageTag, fileExt: fileExt)
            }
        }
        return dict
    }

    /// Build the topics menu item - nil if no title or only in the other language
    func generateMenuItem(language: DefLanguage, languageTag: String) -> [String : Any]? {
        let titleText = title.markdown.get(languageTag).md
        if titleText.isEmpty {
            return nil
        }
        if let soloLanguage = soloLanguage,
            soloLanguage == language.otherLanguage {
            return nil
        }

        return MH([.title: titleText.re_sub("[_`*]+", with: ""),
                   .anchorId: anchorId.urlFragmentEncoded])
    }
}

extension GenData.Item {
    /// Item has keys
    ///     anchor_id
    ///     title -- text title for meta refs & direct-links
    ///     prim|sec_title_html -- language defs, prim/sec is about which to show in dash (etc) mode
    ///     prim|sec_language -- css-appendable class tag for other prim-sec stuff
    ///     any_declaration -- F means direct_link
    ///     dash_type -- for dash links
    ///     dash_name -- title, %-encoded
    ///     primaryUrl -- optional, link for more in primary language
    ///     secondaryUrl -- optional, link for more in secondary language
    ///     def -- optional, popopen item definition
    func generateItem(languageTag: String, fileExt: String) -> [String : Any] {
        let title = flatTitle.get(languageTag)
        var hash = MH([.anchorId: anchorId,
                       .title: title,
                       .dashName: title.urlPathEncoded,
                       .anyDeclaration: primaryTitleHtml != nil || secondaryTitleHtml != nil,
                       .primaryLanguage: primaryLanguage.cssName])

        hash.maybe(.primaryTitleHtml, primaryTitleHtml?.html)
        hash.maybe(.secondaryLanguage, secondaryLanguage?.cssName)
        hash.maybe(.secondaryTitleHtml, secondaryTitleHtml?.html)
        hash.maybe(.dashType, dashType)
        hash.maybe(.primaryUrl, url?.url(fileExtension: fileExt, language: primaryLanguage))
        hash.maybe(.secondaryUrl, secondaryLanguage.flatMap { url?.url(fileExtension: fileExt, language: $0) })
        hash.maybe(.def, def?.generateDef(languageTag: languageTag, fileExt: fileExt))

        return hash
    }
}

extension GenData.Def {
    /// Def is split out because shared between top of page and inside items.
    /// Keys:
    ///   deprecation_html  - optional - is it deprecated
    ///   swift_declaration_html - swift decl
    ///   objc_declaration_html - objc decl --- at least one of these two will be set
    ///   abstract_html - optional - first part of discussion
    ///   overview_html - optional - second part of discussion
    ///   parameters - optional - array of title / parameter_html
    ///   returns_html - optional - returns docs
    func generateDef(languageTag: String, fileExt: String) -> [String : Any] {
        var dict = [String : Any]()
        dict.maybe(.deprecationHtml, deprecation?.get(languageTag).html)
        if !availability.isEmpty {
            dict[.availability] = availability
        }
        dict.maybe(.swiftDeclarationHtml, swiftDeclaration?.html)
        dict.maybe(.objCDeclarationHtml, objCDeclaration?.html)
        dict.maybe(.abstractHtml, abstract?.get(languageTag).html)
        dict.maybe(.overviewHtml, overview?.get(languageTag).html)
        if !params.isEmpty {
            dict[.parameters] = params.map {
                MH([.title: $0.name, .parameterHtml: $0.description.get(languageTag).html])
            }
        }
        dict.maybe(.returnsHtml, returns?.get(languageTag).html)
        return dict
    }
}
