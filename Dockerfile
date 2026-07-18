name: 🐳 Build and Push Docker Image to GHCR

on:
  push:
    branches:
      - main
      - develop
    tags:
      - 'v*'
  pull_request:
    branches:
      - main
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: 📥 Checkout code
        uses: actions/checkout@v4

      - name: 🔧 Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: 🔐 Log in to GitHub Container Registry
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: 📝 Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: 🏗️ Build Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: false
          load: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha

      - name: 🧪 Test Docker image
        run: |
          docker run --rm -d -p 8080:80 --name test-app ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          sleep 3
          curl -f http://localhost:8080/ || exit 1
          docker stop test-app
          echo "✅ Image test passed!"

      - name: 📤 Push Docker image to GHCR
        if: github.event_name != 'pull_request'
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: ✅ Deployment Summary
        if: github.event_name != 'pull_request'
        run: |
          echo "🎉 Docker image pushed successfully!"
          echo ""
          echo "📦 Image Details:"
          echo "Registry: ${{ env.REGISTRY }}"
          echo "Repository: ${{ env.IMAGE_NAME }}"
          echo "Tags:"
          echo "${{ steps.meta.outputs.tags }}"
          echo ""
          echo "🚀 Pull and run with:"
          echo "docker pull ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest"
          echo "docker run -p 80:80 ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest"
