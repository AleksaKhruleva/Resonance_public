import SwiftUI
import PhotosUI
import UIComponents

struct CreatePostView: View {

    private let viewModel: CreateViewModel

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var cropperPayload: CreateViewModel.CropperPayload?

    private var photoPickerTitle: String {
        viewModel.postImageData == nil ? "Выбрать фото из галереи" : "Заменить фото"
    }

    init(viewModel: CreateViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photoSection
                audioSection
                publishButton
            }
            .padding(.bottom, 20)
        }
        .scrollIndicators(.never)
        .loading(viewModel.state == .publishing)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task { await loadImageForCropping(from: newItem) }
        }
        .fullScreenCover(item: $cropperPayload, onDismiss: {
            selectedPhotoItem = nil
        }) { payload in
            ImageCropperView(
                image: payload.image,
                cropShape: .square,
                onCancel: {
                    cropperPayload = nil
                },
                onComplete: { croppedImage in
                    handleCroppedImage(croppedImage)
                }
            )
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Фото для поста")
                .fontSize(20, weight: .semibold)

            if viewModel.postImageData != nil {
                Image(data: viewModel.postImageData)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                selectedPhotoControls
            } else {
                photoPickerButton
            }
        }
    }

    private var photoPickerButton: some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label(
                photoPickerTitle,
                systemImage: "photo.on.rectangle.angled"
            )
            .foregroundStyle(AppColor.text)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .frame(height: AppSize.controlHeight)
            .background(Capsule().fill(AppColor.placeholder.opacity(0.1)))
        }
    }

    private var selectedPhotoControls: some View {
        HStack(spacing: 12) {
            Button {
                selectedPhotoItem = nil
                viewModel.handle(.deletePostImage)
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .fontSize(18)
                    Text("Удалить")
                }
                .foregroundStyle(AppColor.red)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: AppSize.compactControlHeight)
            }
            .background(Capsule().fill(AppColor.red.opacity(0.1)))

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .fontSize(18)
                    Text("Заменить")
                }
                .foregroundStyle(AppColor.text)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: AppSize.compactControlHeight)
                .background(Capsule().fill(AppColor.placeholder.opacity(0.1)))
            }
        }
    }

    private var audioSection: some View {
        AudioDraftView(
            title: "Аудио для поста",
            maxDuration: CreateViewModel.Limits.maxAudioDuration,
            initialRecordingFileURL: viewModel.audioFileURL,
            initialRecordingDuration: viewModel.audioDuration
        ) {
            viewModel.handle(.startAudioRecording)
        } onRecordingCreated: { fileURL, duration in
            viewModel.handle(.finishAudioRecording(fileURL: fileURL, duration: duration))
        } onRecordingDeleted: {
            viewModel.handle(.deleteAudio)
        }
        .id(viewModel.postAudioDraftId)
    }

    private var publishButton: some View {
        Button {
            viewModel.handle(.submitPost)
        } label: {
            Text("Опубликовать")
                .wixFont(.bold, color: AppColor.lightText)
                .frame(maxWidth: .infinity)
                .frame(height: AppSize.controlHeight)
                .opacity(viewModel.isPostReadyForPublish ? 1 : 0.4)
        }
        .background(Capsule().fill(AppColor.blue))
        .padding(.bottom, 20)
        .disabled(!viewModel.isPostReadyForPublish || viewModel.state == .publishing)
    }

    private func loadImageForCropping(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                return
            }

            await MainActor.run {
                cropperPayload = CreateViewModel.CropperPayload(image: image)
            }
        } catch {
            print("Не удалось загрузить фото: \(error)")
        }
    }

    private func handleCroppedImage(_ image: UIImage) {
        if let imageData = image.jpegData(compressionQuality: 0.9) {
            viewModel.handle(.setPostImageData(imageData))
        }
        cropperPayload = nil
    }
}
