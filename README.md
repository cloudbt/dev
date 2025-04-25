# 

```
#!/bin/bash

# 結果を保存するディレクトリ
OUTPUT_DIR="ecr_scan_results"
mkdir -p "$OUTPUT_DIR"

# 日時をファイル名に使用
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 全プライベートリポジトリを取得
echo "リポジトリ一覧を取得中..."
REPOSITORIES=$(aws ecr describe-repositories --query 'repositories[*].repositoryName' --output text)

# 各リポジトリに対して処理
for REPO in $REPOSITORIES; do
  echo "リポジトリ $REPO の最新イメージを取得中..."
  
  # 最新イメージのダイジェストを取得
  LATEST_IMAGE_DIGEST=$(aws ecr describe-images --repository-name "$REPO" \
    --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageDigest' --output text)
  
  if [ "$LATEST_IMAGE_DIGEST" == "None" ] || [ -z "$LATEST_IMAGE_DIGEST" ]; then
    echo "リポジトリ $REPO には有効なイメージが見つかりませんでした。スキップします。"
    continue
  fi
  
  # 最新タグも取得（情報として）
  LATEST_TAG=$(aws ecr describe-images --repository-name "$REPO" \
    --query "imageDetails[?imageDigest=='$LATEST_IMAGE_DIGEST'].imageTags[0]" --output text)
  
  echo "イメージ $REPO:$LATEST_TAG ($LATEST_IMAGE_DIGEST) のスキャンを開始..."
  
  # スキャンを開始
  aws ecr start-image-scan --repository-name "$REPO" --image-id imageDigest="$LATEST_IMAGE_DIGEST"
  
  # スキャンが完了するまで待機
  echo "スキャンが完了するまで待機中..."
  aws ecr wait image-scan-complete --repository-name "$REPO" --image-id imageDigest="$LATEST_IMAGE_DIGEST"
  
  # スキャン結果を取得
  echo "スキャン結果を取得中..."
  aws ecr describe-image-scan-findings --repository-name "$REPO" \
    --image-id imageDigest="$LATEST_IMAGE_DIGEST" \
    > "$OUTPUT_DIR/${REPO}_${LATEST_TAG}_${TIMESTAMP}.json"
  
  echo "リポジトリ $REPO のスキャン結果を保存しました: $OUTPUT_DIR/${REPO}_${LATEST_TAG}_${TIMESTAMP}.json"
done

echo "すべてのイメージのスキャンが完了しました。結果は $OUTPUT_DIR ディレクトリに保存されています。"
```
