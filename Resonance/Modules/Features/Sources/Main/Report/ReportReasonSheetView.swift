import SwiftUI
import Core
import UIComponents

struct ReportReasonSheetView: View {

    private let target: ReportTarget
    private let onSent: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReportReasonSheetViewModel

    init(
        target: ReportTarget,
        onSent: @escaping () -> Void
    ) {
        self.target = target
        self.onSent = onSent
        _viewModel = State(
            initialValue: ReportReasonSheetViewModel(target: target)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                VStack(alignment: .leading, spacing: 20) {
                    reportTextSection
                    sendButton
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppSize.horizontalPadding)
                .padding(.top, 20)
            }
            .navigationTitle("Жалоба")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Отмена")
                            .fontWeight(.medium)
                    }
                    .disabled(viewModel.state == .sending)
                }
            }
            .loading(viewModel.state == .sending)
            .toast(
                viewModel.toast,
                onTap: {
                    viewModel.handle(.dismissToast)
                }
            )
            .onChange(of: viewModel.state) { _, state in
                guard state == .sent else { return }
                onSent()
                dismiss()
            }
        }
    }

    private var reportTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                Text(target.title)
                    .fontSize(20, weight: .semibold)

                Spacer()

                Text(verbatim: "\(viewModel.text.count)/\(ReportReasonSheetViewModel.Limits.maxTextLength)")
                    .foregroundStyle(AppColor.placeholder)
                    .fontSize(AppFontSize.caption)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColor.placeholder.opacity(0.1))

                if viewModel.text.isEmpty {
                    Text("Опишите причину жалобы...")
                        .foregroundStyle(AppColor.placeholder)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                TextEditor(
                    text: Binding(
                        get: { viewModel.text },
                        set: { viewModel.handle(.updateText($0)) }
                    )
                )
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.clear)
            }
            .frame(minHeight: 150)
        }
    }

    private var sendButton: some View {
        Button {
            viewModel.handle(.submit)
        } label: {
            Text("Отправить")
                .wixFont(.bold, color: AppColor.lightText)
                .frame(maxWidth: .infinity)
                .frame(height: AppSize.controlHeight)
                .opacity(viewModel.isReadyForSend ? 1 : 0.4)
        }
        .background(Capsule().fill(AppColor.blue))
        .disabled(!viewModel.isReadyForSend || viewModel.state == .sending)
    }
}
