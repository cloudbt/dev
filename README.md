# 

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ServiceNowUserReadOnlyAccessOrg",
      "Effect": "Allow",
      "Action": [
        "organizations:DescribeOrganization",
        "organizations:ListAccounts",
        "organizations:ListRoots",
        "organizations:ListAccountsForParent",
        "organizations:ListOrganizationalUnitsForParent",
        "organizations:DescribeOrganizationalUnit",
        "organizations:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ServiceNowUserReadOnlyAccessConfig",
      "Effect": "Allow",
      "Action": [
        "config:ListDiscoveredResources",
        "config:SelectResourceConfig",
        "config:BatchGetResourceConfig"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ServiceNowUserReadOnlyAccessConfigAgg",
      "Effect": "Allow",
      "Action": [
        "config:DescribeConfigurationAggregators",
        "config:SelectAggregateResourceConfig",
        "config:BatchGetAggregateResourceConfig"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ServiceNowUserReadOnlyAccessEC2",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeRegions",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceTypes"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ServiceNowUserReadOnlyAccessSSM",
      "Effect": "Allow",
      "Action": [
        "ssm:DescribeInstanceInformation",
        "ssm:ListInventoryEntries",
        "ssm:GetInventory"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ServiceNowUserReadOnlyAccessTag",
      "Effect": "Allow",
      "Action": [
        "tag:GetResources"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ServiceNowUserReadOnlyAccessIAM",
      "Effect": "Allow",
      "Action": [
        "iam:CreateAccessKey",
        "iam:DeleteAccessKey"
      ],
      "Resource": [
        "arn:aws:iam::${ACNNBR}:user/ServiceNowUser"
      ]
    },
    {
      "Sid": "ServiceNowSendCommandAccess",
      "Effect": "Allow",
      "Action": [
        "ssm:SendCommand"
      ],
      "Resource": [
        "arn:aws:ec2:*:${AWS::AccountId}:instance/*",
        "arn:aws:ssm:*:${AWS::AccountId}:document/SG-AWS*"
      ]
    },
    {
      "Sid": "ServiceNowS3BucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::${S3Bucket}/*",
        "arn:aws:s3:::${S3Bucket}"
      ]
    }
  ]
}
```
