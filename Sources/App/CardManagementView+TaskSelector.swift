// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import SwiftUI

extension CardManagementView {
  // MARK: Nested Types

  private enum TaskSelectorLayout {
    static let buttonSpacing: CGFloat = 8
    static let buttonVerticalPadding: CGFloat = 8
    static let listRowPadding: CGFloat = 4
    static let minimumTextScale: CGFloat = 0.75
  }

  // MARK: Content Views

  @ViewBuilder
  internal func taskSelector(
    tasks: [ManagementTask],
    selection: Binding<ManagementTask>
  ) -> some View {
    #if os(iOS)
      Section {
        VStack(spacing: TaskSelectorLayout.buttonSpacing) {
          if tasks.contains(.changePin1) || tasks.contains(.changePin2) {
            HStack(spacing: TaskSelectorLayout.buttonSpacing) {
              taskButton(for: .changePin1, in: tasks, selection: selection)
              taskButton(for: .changePin2, in: tasks, selection: selection)
            }
          }
          if tasks.contains(.resetPin1) || tasks.contains(.resetPin2) {
            HStack(spacing: TaskSelectorLayout.buttonSpacing) {
              taskButton(for: .resetPin1, in: tasks, selection: selection)
              taskButton(for: .resetPin2, in: tasks, selection: selection)
            }
          }
        }
        .padding(.vertical, TaskSelectorLayout.listRowPadding)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .accessibilityIdentifier("managementTask")
      }
    #else
      Picker("Task", selection: selection) {
        ForEach(tasks, id: \.self) { candidate in
          Text(candidate.name).tag(candidate)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .accessibilityIdentifier("managementTask")
    #endif
  }

  #if os(iOS)
    @ViewBuilder
    private func taskButton(
      for candidate: ManagementTask,
      in available: [ManagementTask],
      selection: Binding<ManagementTask>
    ) -> some View {
      let isSelected = selection.wrappedValue == candidate
      let isAvailable = available.contains(candidate)
      let button = Button {
        withAnimation {
          selection.wrappedValue = candidate
        }
      } label: {
        Text(candidate.name)
          .font(.subheadline.weight(isSelected ? .semibold : .regular))
          .lineLimit(1)
          .minimumScaleFactor(TaskSelectorLayout.minimumTextScale)
          .frame(maxWidth: .infinity)
          .padding(.vertical, TaskSelectorLayout.buttonVerticalPadding)
      }
      .disabled(!isAvailable)
      .accessibilityIdentifier(candidate.accessibilityIdentifier)

      if isSelected {
        button
          .buttonStyle(.borderedProminent)
          .tint(Color.accentColor)
      } else {
        button
          .buttonStyle(.bordered)
          .tint(Color.secondary)
      }
    }
  #endif
}
