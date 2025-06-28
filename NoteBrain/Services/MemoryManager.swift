import Foundation
import UIKit
import os.log

class MemoryManager: ObservableObject {
    static let shared = MemoryManager()
    
    private let logger = Logger(subsystem: "kait.dev.NoteBrain", category: "MemoryManager")
    private var memoryWarningObserver: NSObjectProtocol?
    
    @Published var isLowMemory = false
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        logger.warning("Memory warning received")
        isLowMemory = true
        
        // Clear image caches and other memory-intensive resources
        clearImageCaches()
        
        // Force garbage collection
        autoreleasepool {
            // This will help release autoreleased objects
        }
        
        // Reset the flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.isLowMemory = false
        }
    }
    
    private func clearImageCaches() {
        // Clear any image caches that might be holding memory
        URLCache.shared.removeAllCachedResponses()
        
        // Clear any other caches you might have
        // For example, if you're using Kingfisher or similar image caching libraries
    }
    
    func getMemoryUsage() -> (used: UInt64, total: UInt64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let used = UInt64(info.resident_size)
            let total = ProcessInfo.processInfo.physicalMemory
            return (used, total)
        } else {
            return (0, 0)
        }
    }
    
    func logMemoryUsage() {
        let (used, total) = getMemoryUsage()
        let percentage = total > 0 ? Double(used) / Double(total) * 100.0 : 0.0
        logger.info("Memory usage: \(used / 1024 / 1024)MB / \(total / 1024 / 1024)MB (\(String(format: "%.1f", percentage))%)")
    }
} 