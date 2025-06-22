import SwiftUI

struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if isShowing {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(message)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(colorScheme == .dark ? Color(.systemGray6) : Color.black.opacity(0.85))
                        .cornerRadius(12)
                    Spacer()
                }
                .padding(.bottom, 40)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: isShowing)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        isShowing = false
                    }
                }
            }
        } else {
            EmptyView()
        }
    }
} 