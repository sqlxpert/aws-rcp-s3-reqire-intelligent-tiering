# Require S3 Intelligent Tiering!

_Enforce Intelligent Tiering by tagging S3 buckets..._

Still relying on a lifecycle policy to transition S3 objects to
[Intelligent Tiering](https://aws.amazon.com/s3/storage-classes/intelligent-tiering)
after the fact? You're losing money! Set `--storage-class` in scripts and
`StorageClass` in code to avoid the transition charge and start the discount
countdown the moment you create each object.

But how do you make sure _everyone else_ is using Intelligent Tiering?

AWS&nbsp;Config, CloudFormation Hooks, and third-party Terraform tooling with
Open Policy Agent all let you require lifecycle policies on S3 buckets, but
creating objects directly in `INTELLIGENT_TIERING` makes lifecycle transition
rules unnecessary. Checking hundreds or thousands of S3 buckets every
24&nbps;hours with AWS Config isn't cheap, anyway. Neither is licensing and
configuring third-party software.

**I've discovered a practical way to enforce the initial storage class. Every
time an object is created. By any user. In one S3 bucket or thousands. For
free!**

## How to Use It

Deploying a single CloudFormation stack (Terraform is coming) in your
management account creates a resource control policy. It's safe to apply the
RCP throughout your organization, because it doesn't affect existing buckets.

### Strict Bucket Tag

To require Intelligent Tiering for all new objects, tag an S3 bucket with
`cost-s3-require-storage-class-intelligent-tiering` (you can customize the tag
key; the tag value is ignored) and enable
[attribute-based access control](https://aws.amazon.com/blogs/aws/introducing-attribute-based-access-control-for-amazon-s3-general-purpose-buckets)
for the bucket.

Users who forget to...

- add `--storage-class INTELLIGENT_TIERING` when running `aws s3 cp`<br/>or
  `aws s3api put-object`
- set `StorageClass` when calling `client("s3").put_object()` in boto3<br/>(or
  the equivalent in a different AWS SDK)
- set the `x-amz-storage-class` header for the `PubObject` HTTPS API operation

...will receive an "AccessDenied" error with the message "explicit deny in a
resource control policy". If the user misses
"require-storage-class-intelligent-tiering" in the bucket tag, the RCP hint in
the error message tells an administrator where to look.

Pretty soon, setting the storage class will be second-nature.

### Permissive Bucket Tag with Object Tag Override

To require Intelligent Tiering but let users override the requirement, tag an
S3 bucket with
`cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag`
(again customizable) and enable ABAC for the bucket.

A user can set any storage class (or omit the storage class, for `STANDARD`) by
setting the `cost-s3-override-storage-class-intelligent-tiering` _object tag_
when creating an object. Add:

- `--tagging 'cost-s3-override-storage-class-intelligent-tiering='`<br/>when
  running `aws s3api put-object`
- `Tagging="cost-s3-override-storage-class-intelligent-tiering="`<br/>when
  calling `client("s3").put_object()` (or equivalent)
- `x-amz-tagging: cost-s3-override-storage-class-intelligent-tiering=`<br/>
  (Encode `=` as `%3D` if your HTTP library doesn't.)

#### Permissive Bucket Tag Notes

- `aws s3 cp` does not support object tags as of March,&nbsp;2026. To set an
  object tag when creating an object, AWS CLI users must run
  `aws s3api put-object` instead.
- If for some reason you add both bucket tags to a bucket, the permissive one
  wins. Overriding with an object tag will work.
- To override the storage class requirement when overwriting an object or
  creating a new version, be sure to specify the object tag in the new request.

## How It Works

A short resource control policy denies `s3:PutObject` requests if the bucket
has a particular bucket tag and the requester has not set the appropriate
storage class or, if overrides are permitted, the required object tag. The
combination of features needed to make this practical didn't come about until
November,&nbsp;2025.

<detail>
  <summary>AWS feature announcements that made it possible...</summary>

<br/>

 1. With attribute-based access control, S3 now checks bucket tags before
    authorizing requests. Users can see a bucket's tags, so they know what to
    expect. The resource control policy won't break existing systems, because
    any existing bucket is excluded until it is tagged and its ABAC setting is
    enabled.

    November,&nbsp;2025: [Amazon S3 now supports attribute-based access control](https://aws.amazon.com/about-aws/whats-new/2025/11/amazon-s3-attribute-based-access-control)

 2. S3 errors now mention the kind of policy involved. If users miss
    "require-storage-class-intelligent tiering" in a bucket's tag, they can
    report the error to an administrator, who will know where to look because
    the error mentions that a resource control policy is denying permission.

    June,&nbsp;2025: [Amazon S3 extends additional context for HTTP 403 Access Denied error messages to AWS Organizations](https://aws.amazon.com/about-aws/whats-new/2025/06/amazon-s3-context-http-403-access-denied-error-message-aws-organizations)

    - S3 feature wish: If AWS someday applies a related improvement to S3,
      error messages will reveal the ARN of the resource control policy.
      Although users can't view RCPs, knowing the policy ARN would let
      first-time users search an internal knowledge base before asking an
      administrator. What a shame that AWS Organizations uses arbitrary
      resource identifiers rather than user-determined names.
      `arn:aws:organizations::112233445566:policy/o-abcdefghij/resource_control_policy/p-abcdefghij`
      isn't exactly rich with information!

      January, 2026: [AWS introduces additional policy details to access denied error messages](https://aws.amazon.com/about-aws/whats-new/2026/01/additional-policy-details-access-denied-error)

 3. Resource control policies, which S3 supports, make it possible to regulate
    all the buckets in one or more AWS accounts, without having to edit (and
    then control) the bucket policy for each individual bucket.

    November,&nbsp;2024: [Introducing resource control policies (RCPs) to centrally restrict access to AWS resources](https://aws.amazon.com/about-aws/whats-new/2024/11/resource-control-policies-restrict-access-aws-resources)

 4. The `s3:x-amz-storage-class` condition key makes it possible to write
    policies that restrict the storage class for new objects. Initially, the
    scope of such policies was limiting: one bucket, due to its bucket policy,
    one role, with an inline policy. Customer-managed policies that can be
    attached to multiple roles in one AWS account came later, and service
    control policies that can be applied to multiple accounts came much later.

    [December&nbsp;14,&nbsp;2015](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WhatsNew.html#WhatsNew-earlier-doc-history):
    [s3:x-amz-storage-class](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazons3.html#amazons3-s3_x-amz-storage-class)

</detail>

## Installation

### CloudFormation Installation

Instructions coming soon

### Terraform Installation

Coming soon!

## Test

### Resource Control Policy Test

<detail>
  <summary>RCP test script instructions</summary>

<br/>

Test the RCP by running
[test/0test-rcp-s3-require-intelligent-tiering.bash](/test/0test-rcp-s3-require-intelligent-tiering.bash?raw=true)&nbsp;.
The script assumes that you have already run:

- [`aws configure`](https://docs.aws.amazon.com/cli/latest/reference/configure)
  or
  [`aws configure sso`](https://docs.aws.amazon.com/cli/latest/reference/configure/sso.html)
- [`aws login`](https://docs.aws.amazon.com/signin/latest/userguide/command-line-sign-in.html#command-line-sign-in-local-development)
  or
  [`aws sso login`](https://docs.aws.amazon.com/signin/latest/userguide/command-line-sign-in.html#command-line-sign-in-sso)

[CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
is an extremely convenient alternative, if you use the AWS Console.

The IAM role you use for RCP testing must:

- be in an AWS account subject to the resource control policy
- not be in an AWS account subject to the optional service control policy (If
  the SCP applies, then you must use a role allowed by the
  `ScpPrincipalCondition` CloudFormation parameter.)
- have permission to:
  - create, tag, and delete S3 buckets
  - create, tag, and delete S3 objects
  - enable attribute-based access control for S3 buckets: `s3:PutBucketAbac`
  - enable versioning: `s3:PutBucketVersioning`

</detail>

### Service Control Policy Test

Coming soon!

### Report Bugs

Please
[report bugs](/../../issues). Thank you!

## Licenses

|Scope|Link|Included Copy|
|:---|:---|:---|
|Source code, and source code in documentation|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE-CODE.md](/LICENSE-CODE.md)|
|Documentation, including this ReadMe file|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE-DOC.md](/LICENSE-DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
