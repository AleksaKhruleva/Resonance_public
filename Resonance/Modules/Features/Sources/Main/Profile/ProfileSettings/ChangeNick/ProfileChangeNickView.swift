import SwiftUI
import UIComponents
import Core

struct ChangeNickView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ChangeNickViewModel

    @State private var newNick: String = ""
    @FocusState private var fieldIsFocused: Bool

    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.alert != nil },
            set: { newValue in
                if !newValue {
                    viewModel.handle(.dismissAlert)
                }
            }
        )
    }

    init(
        currentNick: String,
        currentUserInfoStore: CurrentUserInfoStore
    ) {
        _newNick = State(wrappedValue: currentNick)
        _viewModel = State(
            wrappedValue: ChangeNickViewModel(
                currentNick: currentNick,
                currentUserInfoStore: currentUserInfoStore
            )
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppBackgroundView()

                ScrollView {
                    VStack {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Text("Отмена")
                                    .fontWeight(.medium)
                                    .padding(4)
                            }
                            .buttonStyle(.glass)
                            .disabled(viewModel.state == .loading)

                            Spacer()
                        }

                        Spacer()

                        VStack(spacing: 32) {
                            Text("Придумайте новый ник")
                                .wixFont(.bold, size: AppFontSize.title)
                                .multilineTextAlignment(.center)

                            TextField("космонавт77", text: $newNick)
                                .wixFont()
                                .focused($fieldIsFocused)
                                .keyboardType(.default)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .replaceDisabled()
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .onChange(of: newNick) { _, newValue in
                                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    newNick = trimmed.prefix(20).lowercased()
                                }
                                .onSubmit {
                                    fieldIsFocused = false
                                    viewModel.handle(.changeNick(newNick: newNick))
                                }

                            VStack(spacing: 5) {
                                Text("Формат ника:")

                                VStack(alignment: .leading) {
                                    HStack(alignment: .top) {
                                        Text("-")
                                        Text("от 3 до 20 символов")
                                    }
                                    HStack(alignment: .top) {
                                        Text("-")
                                        Text("только русские буквы, цифры и нижнее подчеркивание")
                                    }
                                    HStack(alignment: .top) {
                                        Text("-")
                                        Text("начинается и заканчивается буквой или цифрой")
                                    }
                                    HStack(alignment: .top) {
                                        Text("-")
                                        Text("содержит хотя бы одну букву")
                                    }
                                }
                            }
                            .wixFont(color: AppColor.placeholder)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Button {
                            fieldIsFocused = false
                            viewModel.handle(.changeNick(newNick: newNick))
                        } label: {
                            Text("Поменять ник")
                                .wixFont(color: AppColor.background)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColor.blue)
                        .padding(.bottom, 40)
                        .disabled(
                            viewModel.state == .loading ||
                            newNick.isEmpty ||
                            newNick == viewModel.currentNick
                        )
                    }
                    .padding(.horizontal, 20)
                    .frame(minHeight: geo.size.height)
                }
                .scrollIndicators(.never)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .loading(viewModel.state == .loading)
        .toast(
            viewModel.toast,
            onTap: {
                viewModel.handle(.dismissToast)
            }
        )
        .alert(
            viewModel.alert?.title ?? "",
            isPresented: isAlertPresented,
            presenting: viewModel.alert,
            actions: { _ in
                Button("ОК") {
                    viewModel.handle(.dismissAlert)
                }
            },
            message: { alert in
                Text(alert.message)
            }
        )
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            dismiss()
        }
        .task {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(120))
            fieldIsFocused = true
        }
    }
}
