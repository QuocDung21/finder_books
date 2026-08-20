import SwiftUI
import MultipeerConnectivity

struct WiFiSyncControlSheet: View {
    @ObservedObject private var syncManager = LiveCompanionSyncManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var inputIP: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Status Card
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(syncManager.isDirectTCPConnected || !syncManager.connectedPeers.isEmpty ? Color.green : Color.orange)
                            .frame(width: 14, height: 14)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(syncManager.connectionState.title)
                                .font(.system(size: 15, weight: .bold))
                            
                            if syncManager.isDirectTCPConnected {
                                Text("Chế độ: Kết Nối Trực Tiếp Wi-Fi (TCP Ultra-Low Latency)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            } else if !syncManager.connectedPeers.isEmpty {
                                Text("Chế độ: Apple Multipeer P2P Wireless")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Đang lắng nghe & quét thiết bị trong mạng Wi-Fi...")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.platformControlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // Local IP Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("ĐỊA CHỈ IP THIẾT BỊ NÀY:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "wifi")
                            .foregroundColor(.accentColor)
                        
                        Text(syncManager.localIP)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        
                        Spacer()
                        
                        #if os(macOS)
                        Button("Sao Chép IP") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(syncManager.localIP, forType: .string)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        #endif
                    }
                    .padding(12)
                    .background(Color.platformControlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                
                // Direct IP Connection Input (Useful when router blocks Multicast / Bonjour)
                VStack(alignment: .leading, spacing: 8) {
                    Text("KẾT NỐI BẰNG IP (NẾU ROUTER CHẶN TỰ ĐỘNG TÌM):")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        TextField("Nhập IP máy Mac (ví dụ: 192.168.1.15)", text: $inputIP)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        
                        Button {
                            syncManager.connectDirectIP(ip: inputIP)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                Text("Kết Nối")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(inputIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
                // Discovered Peers List
                if !syncManager.discoveredPeers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("THIẾT BỊ TÌM THẤY TRONG MẠNG:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        ForEach(syncManager.discoveredPeers, id: \.self) { peer in
                            HStack {
                                Image(systemName: "ipad.and.iphone")
                                    .foregroundColor(.accentColor)
                                
                                Text(peer.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                
                                Spacer()
                                
                                Button("Ghép Nối") {
                                    syncManager.connectToPeer(peer)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .padding(10)
                            .background(Color.platformControlBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                
                Spacer()
                
                // Footer Action
                HStack(spacing: 12) {
                    Button {
                        syncManager.restartDiscovery()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Quét Lại Mạng Wi-Fi")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    
                    Button("Đóng") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding(20)
            .navigationTitle("Đồng Bộ Wi-Fi (Mac ↔ iPad)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                if !syncManager.manualConnectIP.isEmpty {
                    inputIP = syncManager.manualConnectIP
                }
            }
        }
        .frame(minWidth: 420, minHeight: 460)
    }
}
