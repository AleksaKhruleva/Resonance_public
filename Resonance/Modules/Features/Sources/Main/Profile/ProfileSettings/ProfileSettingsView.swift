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

    @Environment(CurrentUserInfoStore.self) private var currentUserInfoStore

    @State private var viewModel: ProfileSettingsViewModel
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var cropperPayload: CropperPayload?
    @State private var activeAlert: ProfileSettingsAlert?
    @State private var isPhotoPickerPresented = false
    @State private var isChangeNickViewPresented = false
    @State private var isChangeEmailViewPresented = false

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
        currentUser: CurrentUserInfo,
        onLogout: @escaping () -> Void = {}
    ) {
        _viewModel = State(
            initialValue: ProfileSettingsViewModel(
                currentUser: currentUser,
                onLogout: onLogout
            )
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
        .fullScreenCover(isPresented: $isChangeNickViewPresented, content: {
            ChangeNickView(
                currentNick: viewModel.nick,
                currentUserInfoStore: currentUserInfoStore
            )
        })
        .fullScreenCover(isPresented: $isChangeEmailViewPresented, content: {
            ChangeEmailView(currentEmail: viewModel.email)
        })
        .onAppear {
            viewModel.handle(.loadProfile)
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileSettingsUpdated)) { notification in
            guard
                let userNick = notification.userInfo?[ProfileSettingsUpdateNotification.userNickKey] as? String
            else {
                return
            }

            let newNick = notification.userInfo?[ProfileSettingsUpdateNotification.newUserNickKey] as? String
            let avatarData = notification.userInfo?[ProfileSettingsUpdateNotification.avatarDataKey] as? Data
            let avatarWasUpdated = notification.userInfo?[ProfileSettingsUpdateNotification.avatarWasUpdatedKey] as? Bool ?? false

            viewModel.handle(
                .profileSettingsUpdated(
                    userNick: userNick,
                    newNick: newNick,
                    avatarData: avatarData,
                    avatarWasUpdated: avatarWasUpdated
                )
            )
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
                guard viewModel.isAvatarActionAvailable else { return }
                activeAlert = .editAvatar(hasAvatar: viewModel.hasAvatar)
            }

            SettingsDivider()

            SettingsNavigationRow(
                iconName: "person.text.rectangle",
                title: "Изменить ник"
            ) {
                isChangeNickViewPresented = true
            }

            SettingsDivider()

            SettingsNavigationRow(
                iconName: "at",
                title: "Изменить почту"
            ) {
                isChangeEmailViewPresented = true
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
                activeAlert = .logout
            }

            SettingsDivider()

            SettingsNavigationRow(
                isDestructive: true,
                iconName: "trash",
                title: "Удалить аккаунт"
            ) {
                activeAlert = .deleteAccount
            }
        }
    }

    private func makeAlertMessage(for alert: ProfileSettingsAlert) -> some View {
        Text(alert.message)
    }

    @ViewBuilder
    private func makeAlertActions(for alert: ProfileSettingsAlert) -> some View {
        switch alert {
        case .logout:
            Button("Отмена", role: .cancel) {}
            Button("Выйти", role: .destructive) {
                activeAlert = nil
                viewModel.handle(.logout)
            }

        case .deleteAccount:
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                activeAlert = nil
                viewModel.handle(.deleteAccount)
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
