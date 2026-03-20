import SwiftUI
import PhotosUI
import UIComponents
import Core

enum ProfileSettingsAction {
    case changeAvatar
    case changeNick
    case changeEmail
    case logout
    case deleteAccount
}

struct ProfileSettingsView: View {

    private struct CropperPayload: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    @State private var viewModel: ProfileSettingsViewModel
    @State private var isPhotoPickerPresented = false
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var cropperPayload: CropperPayload?

    @State private var activeAlert: ProfileSettingsAlert?
    private let onLogout: () -> Void

    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { activeAlert != nil },
            set: { newValue in
                if !newValue {
                    activeAlert = nil
                }
            }
        )
    }

    init(
        currentUser: CurrentUser,
        onLogout: @escaping () -> Void = {}
    ) {
        self.onLogout = onLogout
        _viewModel = State(
            initialValue: ProfileSettingsViewModel(currentUser: currentUser)
        )
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(spacing: 16) {
                    avatarSection
                    personalInfoSection
                    dangerSection
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
        .toolbarTitle("Настройки профиля")
        .toolbar(.hidden, for: .tabBar)
        .loading(viewModel.isLoading)
        .toast(
            viewModel.toast,
            onTap: {
                viewModel.handle(.dismissToast)
            }
        )
        .alert(
            activeAlert?.title ?? "",
            isPresented: isAlertPresented,
            presenting: activeAlert,
            actions: makeAlertActions,
            message: makeAlertMessage
        )
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedAvatarItem,
            matching: .images
        )
        .onChange(of: selectedAvatarItem) { _, newItem in
            Task { await loadImageForCropping(from: newItem) }
        }
        .fullScreenCover(item: $cropperPayload, onDismiss: {
            selectedAvatarItem = nil
        }) { payload in
            ImageCropperView(
                image: payload.image,
                cropShape: .circle,
                onCancel: {
                    cropperPayload = nil
                },
                onComplete: { croppedImage in
                    handleCroppedImage(croppedImage)
                }
            )
        }
        .onAppear {
            viewModel.handle(.loadProfile)
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 4) {
            AvatarView(imageData: viewModel.avatarData, frame: 200)
                .padding(.bottom, 4)
            Text(viewModel.nick)
            Text(verbatim: viewModel.email)
        }
        .wixFont(.bold)
    }

    private var personalInfoSection: some View {
        SettingsSection(title: "Персональные данные") {
            SettingsNavigationRow(
                iconName: "camera",
                title: viewModel.hasAvatar ? "Изменить аватар" : "Установить аватар"
            ) {
                handleAction(.changeAvatar)
            }

            SettingsDivider()

            SettingsNavigationRow(
                iconName: "person.text.rectangle",
                title: "Изменить ник"
            ) {
                handleAction(.changeNick)
            }

            SettingsDivider()

            SettingsNavigationRow(
                iconName: "at",
                title: "Изменить почту"
            ) {
                handleAction(.changeEmail)
            }
        }
    }

    private var dangerSection: some View {
        SettingsSection(title: "Опасные действия") {
            SettingsNavigationRow(
                isDestructive: true,
                iconName: "rectangle.portrait.and.arrow.right",
                title: "Выйти из аккаунта"
            ) {
                handleAction(.logout)
            }

            SettingsDivider()

            SettingsNavigationRow(
                isDestructive: true,
                iconName: "trash",
                title: "Удалить аккаунт"
            ) {
                handleAction(.deleteAccount)
            }
        }
    }

    @ViewBuilder
    private func makeAlertActions(for alert: ProfileSettingsAlert) -> some View {
        switch alert {
        case .logout:
            Button("Отмена", role: .cancel) {}
            Button("Выйти", role: .destructive) {
                performConfirmedAction(.logout)
            }

        case .deleteAccount:
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                performConfirmedAction(.deleteAccount)
            }

        case .editAvatar(let hasAvatar):
            Button("Выбрать новую фотографию") {
                activeAlert = nil
                isPhotoPickerPresented = true
            }

            if hasAvatar {
                Button("Удалить текущую фотографию", role: .destructive) {
                    activeAlert = nil
                    viewModel.handle(.deleteAvatar)
                }
            }

            Button("Ничего не менять", role: .cancel) {}
        }
    }

    private func makeAlertMessage(for alert: ProfileSettingsAlert) -> some View {
        Text(alert.message)
    }

    private func handleAction(_ action: ProfileSettingsAction) {
        switch action {
        case .changeAvatar:
            guard viewModel.isAvatarActionAvailable else { return }
            activeAlert = .editAvatar(hasAvatar: viewModel.hasAvatar)
        case .changeNick:
            break
        case .changeEmail:
            break
        case .logout:
            activeAlert = .logout
        case .deleteAccount:
            activeAlert = .deleteAccount
        }
    }

    private func performConfirmedAction(_ action: ProfileSettingsAction) {
        switch action {
        case .changeAvatar:
            break
        case .changeNick:
            break
        case .changeEmail:
            break
        case .logout:
            activeAlert = nil
            onLogout()
        case .deleteAccount:
            break
        }
    }

    private func loadImageForCropping(from item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                await MainActor.run {
                    viewModel.handle(.avatarSelectionFailed)
                    selectedAvatarItem = nil
                }
                return
            }

            await MainActor.run {
                cropperPayload = CropperPayload(image: image)
            }
        } catch {
            await MainActor.run {
                viewModel.handle(.avatarSelectionFailed)
                selectedAvatarItem = nil
            }
        }
    }

    private func handleCroppedImage(_ image: UIImage) {
        if let imageData = image.jpegData(compressionQuality: 0.9) {
            viewModel.handle(.changeAvatar(imageData))
        } else {
            viewModel.handle(.avatarSelectionFailed)
        }
        cropperPayload = nil
    }
}
