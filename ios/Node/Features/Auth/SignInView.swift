import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showError = false

    var body: some View {
        ZStack {
            NodeColor.graphite.ignoresSafeArea()

            VStack(spacing: NodeSpacing.sp12) {
                Spacer()

                VStack(spacing: NodeSpacing.sp3) {
                    Text("Node")
                        .font(NodeFont.display(NodeFont.display, weight: .light))
                        .tracking(-1)
                        .foregroundStyle(NodeColor.bone)
                    + Text(".")
                        .font(NodeFont.display(NodeFont.display, weight: .light))
                        .foregroundStyle(NodeColor.moss)

                    MetaLabel(text: "植物の時間を残す", color: NodeColor.fog)
                }

                Spacer()

                VStack(spacing: NodeSpacing.sp4) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email]
                        request.nonce = viewModel.prepareAppleSignIn()
                    } onCompletion: { result in
                        Task { await viewModel.handleAppleSignIn(result: result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))

                    Button("オフラインで続ける") {
                        viewModel.continueOffline()
                    }
                    .font(NodeFont.text(NodeFont.callout))
                    .foregroundStyle(NodeColor.fog)
                }
                .padding(.horizontal, NodeSpacing.sp6)
                .padding(.bottom, NodeSpacing.sp12)
            }

            if viewModel.isLoading {
                ProgressView()
                    .tint(NodeColor.moss)
            }
        }
        .alert("サインインエラー", isPresented: $showError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showError = newValue != nil
        }
    }
}
