// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import SwiftUI

  /// The Time-Stamp Authorities pane: one table, in the order asked.
  ///
  /// Every cell is edited in place, like a spreadsheet: the address,
  /// the Basic-auth username and password beside it - empty for a
  /// public service - and an open line at the bottom waiting for the
  /// next authority. Each row carries its own delete control, so
  /// nothing depends on a selection. Whoever configures an authority
  /// answers for it; the only badge is a warning on an address this
  /// app could not even ask.
  internal struct TimestampAuthoritiesSettingsView: View {
    private typealias Row = TimestampAuthoritiesModel.Row

    private static let paneWidth: CGFloat = 640
    private static let listHeight: CGFloat = 170
    private static let cellSpacing: CGFloat = 8
    private static let legendSpacing: CGFloat = 14
    private static let legendSymbolSpacing: CGFloat = 4

    /// The status column's width, which grows with the text beside it.
    @ScaledMetric(relativeTo: .body)
    private var badgeWidth: CGFloat = 16

    /// The width of the two credential columns, which grow with the
    /// text in them rather than clipping it.
    @ScaledMetric(relativeTo: .body)
    private var credentialWidth: CGFloat = 110

    @State private var model = TimestampAuthoritiesModel()
    @FocusState private var focusedRow: UUID?

    internal var body: some View {
      Form {
        Section {
          table
          HStack {
            Spacer()
            Button("Restore Defaults") {
              model.restoreDefaults()
            }
            .disabled(model.isShippedSet)
          }
        } footer: {
          legend
        }
      }
      .formStyle(.grouped)
      .frame(minWidth: Self.paneWidth)
      .onChange(of: model.rows) { _, _ in
        model.reconcile(focused: focusedRow)
      }
      .onChange(of: focusedRow) { _, now in
        model.tidy(keeping: now)
      }
    }

    /// The table itself, dragged into the order the services are
    /// asked.
    @ViewBuilder private var table: some View {
      List {
        columnHeader
        ForEach(Bindable(model).rows, id: \.rowID) { $row in
          tableRow($row)
        }
        .onMove { source, destination in
          model.rows.move(fromOffsets: source, toOffset: destination)
        }
      }
      .frame(minHeight: Self.listHeight)
      .accessibilityLabel("Time-stamp authorities, used in this order")
    }

    /// The column names, aligned over their cells.
    @ViewBuilder private var columnHeader: some View {
      HStack(spacing: Self.cellSpacing) {
        Spacer().frame(width: badgeWidth)
        Text("Address").frame(maxWidth: .infinity, alignment: .leading)
        Text("Username").frame(width: credentialWidth, alignment: .leading)
        Text("Password").frame(width: credentialWidth, alignment: .leading)
        Spacer().frame(width: badgeWidth)
      }
      .font(.footnote)
      .foregroundStyle(.secondary)
    }

    /// The legend line that appears only while some row earns it.
    @ViewBuilder private var legend: some View {
      HStack(spacing: Self.legendSpacing) {
        if model.rows.contains(where: { row in
          !row.address.isEmpty && !AuthoritySchemeResolver.isUsable(row.address)
        }) {
          legendEntry(
            "exclamationmark.triangle.fill",
            AnyShapeStyle(.orange),
            "Not a usable address"
          )
        }
      }
      .font(.footnote)
    }

    /// One row: badge, three cells, delete.
    @ViewBuilder
    private func tableRow(_ row: Binding<Row>) -> some View {
      HStack(spacing: Self.cellSpacing) {
        badge(row)
        TextField(
          model.isOpenLine(row.wrappedValue) ? "Add an authority" : "Address",
          text: row.address
        )
        .textFieldStyle(.plain)
        .focused($focusedRow, equals: row.wrappedValue.rowID)
        TextField("Username", text: row.username)
          .textFieldStyle(.plain)
          .frame(width: credentialWidth)
          .focused($focusedRow, equals: row.wrappedValue.rowID)
        SecureField("Password", text: row.password)
          .textFieldStyle(.plain)
          .frame(width: credentialWidth)
          .focused($focusedRow, equals: row.wrappedValue.rowID)
        deleteControl(row.wrappedValue)
      }
    }

    /// The row's badge: a warning on an address this app could not
    /// even ask, and otherwise nothing.
    @ViewBuilder
    private func badge(_ row: Binding<Row>) -> some View {
      let address = row.wrappedValue.address
      if !address.isEmpty, !AuthoritySchemeResolver.isUsable(address) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
          .frame(width: badgeWidth)
          .accessibilityLabel("not a usable address")
      } else {
        Spacer().frame(width: badgeWidth)
      }
    }

    /// The row's own delete control; the open line has nothing to
    /// delete.
    @ViewBuilder
    private func deleteControl(_ row: Row) -> some View {
      if model.isOpenLine(row) {
        Spacer().frame(width: badgeWidth)
      } else {
        Button {
          model.rows.removeAll { $0.rowID == row.rowID }
        } label: {
          Image(systemName: "trash")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .frame(width: badgeWidth)
        .help("Remove this authority")
        .accessibilityLabel("Remove \(row.address)")
      }
    }

    /// One legend item, symbol and meaning.
    @ViewBuilder
    private func legendEntry(
      _ symbol: String, _ style: AnyShapeStyle, _ text: LocalizedStringKey
    ) -> some View {
      HStack(spacing: Self.legendSymbolSpacing) {
        Image(systemName: symbol)
          .foregroundStyle(style)
          .accessibilityHidden(true)
        Text(text).foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .combine)
    }
  }

#endif
