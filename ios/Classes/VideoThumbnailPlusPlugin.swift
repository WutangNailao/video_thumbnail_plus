import Flutter
import UIKit
import AVFoundation
import CommonCrypto

public class VideoThumbnailPlusPlugin: NSObject, FlutterPlugin {
    private static let FORMAT_JPEG = 0
    private static let FORMAT_PNG = 1
    private static let FORMAT_WEBP = 2

    private let queue = DispatchQueue(label: "world.nailao.video_thumbnail_plus", qos: .userInitiated)

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "world.nailao.flutter.plugin/video_thumbnail_plus",
            binaryMessenger: registrar.messenger()
        )
        let instance = VideoThumbnailPlusPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        switch call.method {
        case "file":
            handleThumbnailFile(args: args, result: result)
        case "data":
            handleThumbnailData(args: args, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleThumbnailFile(args: [String: Any], result: @escaping FlutterResult) {
        let video = args["video"] as? String ?? ""
        let headers = args["headers"] as? [String: String] ?? [:]
        let path = args["path"] as? String ?? ""
        let format = args["format"] as? Int ?? VideoThumbnailPlusPlugin.FORMAT_PNG
        let maxHeight = args["maxh"] as? Int ?? 0
        let maxWidth = args["maxw"] as? Int ?? 0
        let timeMs = args["timeMs"] as? Int ?? 0
        let quality = args["quality"] as? Int ?? 100

        queue.async {
            do {
                let filePath = try self.generateThumbnailFile(
                    video: video,
                    headers: headers,
                    path: path,
                    format: format,
                    maxHeight: maxHeight,
                    maxWidth: maxWidth,
                    timeMs: timeMs,
                    quality: quality
                )
                DispatchQueue.main.async {
                    result(filePath)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "THUMBNAIL_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func handleThumbnailData(args: [String: Any], result: @escaping FlutterResult) {
        let video = args["video"] as? String ?? ""
        let headers = args["headers"] as? [String: String] ?? [:]
        let format = args["format"] as? Int ?? VideoThumbnailPlusPlugin.FORMAT_PNG
        let maxHeight = args["maxh"] as? Int ?? 0
        let maxWidth = args["maxw"] as? Int ?? 0
        let timeMs = args["timeMs"] as? Int ?? 0
        let quality = args["quality"] as? Int ?? 100

        queue.async {
            do {
                let data = try self.generateThumbnailData(
                    video: video,
                    headers: headers,
                    format: format,
                    maxHeight: maxHeight,
                    maxWidth: maxWidth,
                    timeMs: timeMs,
                    quality: quality
                )
                DispatchQueue.main.async {
                    result(FlutterStandardTypedData(bytes: data))
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "THUMBNAIL_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func generateThumbnailFile(
        video: String,
        headers: [String: String],
        path: String,
        format: Int,
        maxHeight: Int,
        maxWidth: Int,
        timeMs: Int,
        quality: Int
    ) throws -> String {
        guard let image = try createThumbnail(
            video: video,
            headers: headers,
            maxHeight: maxHeight,
            maxWidth: maxWidth,
            timeMs: timeMs
        ) else {
            throw NSError(domain: "VideoThumbnailPlus", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate thumbnail"])
        }

        let fileExtension: String
        let imageData: Data?

        switch format {
        case VideoThumbnailPlusPlugin.FORMAT_JPEG:
            fileExtension = "jpg"
            imageData = image.jpegData(compressionQuality: CGFloat(quality) / 100.0)
        case VideoThumbnailPlusPlugin.FORMAT_PNG:
            fileExtension = "png"
            imageData = image.pngData()
        case VideoThumbnailPlusPlugin.FORMAT_WEBP:
            fileExtension = "webp"
            // iOS doesn't have native WebP support, fallback to PNG
            imageData = image.pngData()
        default:
            fileExtension = "png"
            imageData = image.pngData()
        }

        guard let data = imageData else {
            throw NSError(domain: "VideoThumbnailPlus", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }

        let outputDir: URL
        if !path.isEmpty {
            outputDir = URL(fileURLWithPath: path)
        } else {
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            outputDir = cacheDir.appendingPathComponent("video_thumbnails")
        }

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)

        let fileName = "\(md5(video))_\(timeMs).\(fileExtension)"
        let outputFile = outputDir.appendingPathComponent(fileName)

        try data.write(to: outputFile)

        return outputFile.path
    }

    private func generateThumbnailData(
        video: String,
        headers: [String: String],
        format: Int,
        maxHeight: Int,
        maxWidth: Int,
        timeMs: Int,
        quality: Int
    ) throws -> Data {
        guard let image = try createThumbnail(
            video: video,
            headers: headers,
            maxHeight: maxHeight,
            maxWidth: maxWidth,
            timeMs: timeMs
        ) else {
            throw NSError(domain: "VideoThumbnailPlus", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate thumbnail"])
        }

        let imageData: Data?

        switch format {
        case VideoThumbnailPlusPlugin.FORMAT_JPEG:
            imageData = image.jpegData(compressionQuality: CGFloat(quality) / 100.0)
        case VideoThumbnailPlusPlugin.FORMAT_PNG:
            imageData = image.pngData()
        case VideoThumbnailPlusPlugin.FORMAT_WEBP:
            // iOS doesn't have native WebP support, fallback to PNG
            imageData = image.pngData()
        default:
            imageData = image.pngData()
        }

        guard let data = imageData else {
            throw NSError(domain: "VideoThumbnailPlus", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }

        return data
    }

    private func createThumbnail(
        video: String,
        headers: [String: String],
        maxHeight: Int,
        maxWidth: Int,
        timeMs: Int
    ) throws -> UIImage? {
        let videoURL: URL

        if video.hasPrefix("http://") || video.hasPrefix("https://") {
            guard let url = URL(string: video) else {
                throw NSError(domain: "VideoThumbnailPlus", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }
            videoURL = url
        } else if video.hasPrefix("file://") {
            videoURL = URL(fileURLWithPath: String(video.dropFirst(7)))
        } else {
            videoURL = URL(fileURLWithPath: video)
        }

        let asset: AVAsset
        if !headers.isEmpty {
            asset = AVURLAsset(url: videoURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        } else {
            asset = AVAsset(url: videoURL)
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero

        if maxWidth > 0 || maxHeight > 0 {
            let width = maxWidth > 0 ? maxWidth : maxHeight
            let height = maxHeight > 0 ? maxHeight : maxWidth
            generator.maximumSize = CGSize(width: width, height: height)
        }

        let time = CMTime(value: CMTimeValue(timeMs), timescale: 1000)

        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            throw error
        }
    }

    private func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_MD5($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
