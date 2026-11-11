//
//  BarManSection.swift
//  BarMan
//

import SwiftUI

struct BarManSectionOptions: OptionSet {
    let rawValue: Int

    static let isBordered = BarManSectionOptions(rawValue: 1 << 0)

    static let plain: BarManSectionOptions = []
    static let `default`: BarManSectionOptions = [.isBordered]
}

struct BarManSection<Header: View, Content: View, Footer: View>: View {
    private let header: Header
    private let content: Content
    private let footer: Footer
    private let spacing: CGFloat
    private let options: BarManSectionOptions

    private var isBordered: Bool { options.contains(.isBordered) }

    init(
        spacing: CGFloat = 10,
        options: BarManSectionOptions = .default,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.spacing = spacing
        self.options = options
        self.header = header()
        self.content = content()
        self.footer = footer()
    }

    init(
        spacing: CGFloat = 10,
        options: BarManSectionOptions = .default,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) where Header == EmptyView {
        self.init(spacing: spacing, options: options) {
            EmptyView()
        } content: {
            content()
        } footer: {
            footer()
        }
    }

    init(
        spacing: CGFloat = 10,
        options: BarManSectionOptions = .default,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) where Footer == EmptyView {
        self.init(spacing: spacing, options: options) {
            header()
        } content: {
            content()
        } footer: {
            EmptyView()
        }
    }

    init(
        spacing: CGFloat = 10,
        options: BarManSectionOptions = .default,
        @ViewBuilder content: () -> Content
    ) where Header == EmptyView, Footer == EmptyView {
        self.init(spacing: spacing, options: options) {
            EmptyView()
        } content: {
            content()
        } footer: {
            EmptyView()
        }
    }

    init(
        _ title: LocalizedStringKey,
        spacing: CGFloat = 10,
        options: BarManSectionOptions = .default,
        @ViewBuilder content: () -> Content
    ) where Header == Text, Footer == EmptyView {
        self.init(spacing: spacing, options: options) {
            Text(title)
                .font(.headline)
        } content: {
            content()
        }
    }

    var body: some View {
        if isBordered {
            BarManGroupBox(padding: spacing) {
                header
            } content: {
                content
                    .frame(maxWidth: .infinity)
            } footer: {
                footer
            }
        } else {
            VStack(alignment: .leading) {
                header
                content
                    .frame(maxWidth: .infinity)
                footer
            }
        }
    }
}
