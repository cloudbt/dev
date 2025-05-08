# 

```
# ECRレジストリスキャン設定
resource "aws_ecr_registry_scanning_configuration" "main" {
  scan_type = "ENHANCED"  # 拡張スキャン（Amazon Inspector）を使用
  
  # 連続スキャンの設定
  rule {
    scan_frequency = "CONTINUOUS_SCAN"
    repository_filter {
      filter      = "asp-dev-web-api"
      filter_type = "WILDCARD"
    }
    repository_filter {
      filter      = "asp-dev-web-ui"
      filter_type = "WILDCARD"
    }
    repository_filter {
      filter      = "maxiv-dev-admin-web-api"
      filter_type = "WILDCARD"
    }
    repository_filter {
      filter      = "maxiv-dev-admin-web-ui"
      filter_type = "WILDCARD"
    }
  }
  #  プッシュ時スキャンの設定
  rule {
    scan_frequency = "SCAN_ON_PUSH"
    repository_filter {
      filter      = "asp-dev-web-api"
      filter_type = "WILDCARD"
    }
    repository_filter {
      filter      = "asp-dev-web-ui"
      filter_type = "WILDCARD"
    }
    repository_filter {
      filter      = "maxiv-dev-admin-web-api"
      filter_type = "WILDCARD"
    }
    repository_filter {
      filter      = "maxiv-dev-admin-web-ui"
      filter_type = "WILDCARD"
    }
  }
}
```
