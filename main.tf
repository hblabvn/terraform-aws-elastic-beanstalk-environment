# Define composite variables for resources
module "label" {
  source     = "git::https://github.com/cloudposse/terraform-terraform-label.git?ref=tags/0.1.6"
  namespace  = "${var.namespace}"
  name       = "${var.name}"
  stage      = "${var.stage}"
  delimiter  = "${var.delimiter}"
  attributes = "${var.attributes}"
  tags       = "${var.tags}"
}

data "aws_region" "default" {}

#
# IAM roles
#
module "iam_roles" {
  source = "git::https:/github.com/thanhbn87/terraform-aws-iam-role-elasticbeanstalk.git?ref=tags/0.1.0"

  name        = "${var.name}"
  namespace   = "${var.namespace}"
  project_env = "${var.project_env}"
  project_env_short = "${var.project_env_short}"

  temp_file_assumerole       = "${var.temp_file_assumerole}"
  temp_file_policy           = "${var.temp_file_policy}"
  iam_instance_profile       = "${var.iam_instance_profile}"
  service_name               = "${var.service_name}"
  enhanced_reporting_enabled = "${var.enhanced_reporting_enabled}"
  ssm_enabled                = "${var.ssm_enabled}"
  ssm_registration_limit     = "${var.autoscale_max}"

  tags = "${var.tags}"
}

#
# Full list of options:
# http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options-general.html#command-options-general-elasticbeanstalkmanagedactionsplatformupdate
#
resource "aws_elastic_beanstalk_environment" "default" {
  name        = "${module.label.id}"
  application = "${var.app}"
  description = "${var.description}"

  tier                = "${var.tier}"
  solution_stack_name = "${var.solution_stack_name}"

  wait_for_ready_timeout = "${var.wait_for_ready_timeout}"

  version_label = "${var.version_label}"

  tags = "${module.label.tags}"

  # because of https://github.com/terraform-providers/terraform-provider-aws/issues/3963
  lifecycle {
    ignore_changes = ["tags"]
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = "${var.vpc_id}"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "${var.associate_public_ip_address}"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "${join(",", var.private_subnets)}"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = "${join(",", var.public_subnets)}"
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateType"
    value     = "${var.rolling_update_type}"
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "MinInstancesInService"
    value     = "${var.updating_min_in_service}"
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "${var.rolling_update_type == "Immutable" ? "Immutable" : "${var.deploy_policy}"}"
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "MaxBatchSize"
    value     = "${var.updating_max_batch}"
  }

  ###=========================== Logging ========================== ###

  setting {
    namespace = "aws:elasticbeanstalk:hostmanager"
    name      = "LogPublicationControl"
    value     = "${var.enable_log_publication_control ? "true" : "false"}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "${var.enable_stream_logs ? "true" : "false"}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "DeleteOnTerminate"
    value     = "${var.logs_delete_on_terminate ? "true" : "false"}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = "${var.logs_retention_in_days}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs:health"
    name      = "HealthStreamingEnabled"
    value     = "${var.health_streaming_enabled ? "true" : "false"}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs:health"
    name      = "DeleteOnTerminate"
    value     = "${var.health_streaming_delete_on_terminate ? "true" : "false"}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs:health"
    name      = "RetentionInDays"
    value     = "${var.health_streaming_retention_in_days}"
  }

  ###=========================== Autoscale trigger ========================== ###

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "MeasureName"
    value     = "${var.autoscale_measure_name}"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Statistic"
    value     = "${var.autoscale_statistic}"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Unit"
    value     = "${var.autoscale_unit}"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "LowerThreshold"
    value     = "${var.autoscale_lower_bound}"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "LowerBreachScaleIncrement"
    value     = "${var.autoscale_lower_increment}"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "UpperThreshold"
    value     = "${var.autoscale_upper_bound}"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "UpperBreachScaleIncrement"
    value     = "${var.autoscale_upper_increment}"
  }

  ###=========================== Autoscale trigger ========================== ###

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = "${join(",", var.security_groups)}"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SSHSourceRestriction"
    value     = "tcp,22,22,${var.ssh_source_restriction}"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "${var.instance_type}"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "${var.iam_instance_profile == "" ? module.iam_roles.iam_instance_profile : var.iam_instance_profile}"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "EC2KeyName"
    value     = "${var.keypair}"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeSize"
    value     = "${var.root_volume_size}"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeType"
    value     = "${var.root_volume_type}"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "Availability Zones"
    value     = "${var.availability_zones}"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "${var.autoscale_min}"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "${var.autoscale_max}"
  }
  setting {
    namespace = "aws:elb:loadbalancer"
    name      = "CrossZone"
    value     = "true"
  }
  setting {
    namespace = "aws:elb:loadbalancer"
    name      = "SecurityGroups"
    value     = "${join(",", var.loadbalancer_security_groups)}"
  }
  setting {
    namespace = "aws:elb:loadbalancer"
    name      = "ManagedSecurityGroup"
    value     = "${var.loadbalancer_managed_security_group}"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "${var.environment_type == "LoadBalanced" ? var.elb_scheme : ""}"
  }
  setting {
    namespace = "aws:elb:listener"
    name      = "ListenerProtocol"
    value     = "HTTP"
  }
  setting {
    namespace = "aws:elb:listener"
    name      = "InstancePort"
    value     = "${var.application_port}"
  }
  setting {
    namespace = "aws:elb:listener"
    name      = "ListenerEnabled"
    value     = "${var.http_listener_enabled  == "true" || var.loadbalancer_certificate_arn == "" ? "true" : "false"}"
  }
  setting {
    namespace = "aws:elb:listener:443"
    name      = "ListenerProtocol"
    value     = "HTTPS"
  }
  setting {
    namespace = "aws:elb:listener:443"
    name      = "InstancePort"
    value     = "${var.application_port}"
  }
  setting {
    namespace = "aws:elb:listener:443"
    name      = "SSLCertificateId"
    value     = "${var.loadbalancer_certificate_arn}"
  }
  setting {
    namespace = "aws:elb:listener:443"
    name      = "ListenerEnabled"
    value     = "${var.loadbalancer_certificate_arn == "" ? "false" : "true"}"
  }
  setting {
    namespace = "aws:elb:listener:${var.ssh_listener_port}"
    name      = "ListenerProtocol"
    value     = "TCP"
  }
  setting {
    namespace = "aws:elb:listener:${var.ssh_listener_port}"
    name      = "InstancePort"
    value     = "22"
  }
  setting {
    namespace = "aws:elb:listener:${var.ssh_listener_port}"
    name      = "ListenerEnabled"
    value     = "${var.ssh_listener_enabled}"
  }
  setting {
    namespace = "aws:elb:policies"
    name      = "ConnectionSettingIdleTimeout"
    value     = "${var.ssh_listener_enabled == "true" ? "3600" : "60"}"
  }
  setting {
    namespace = "aws:elb:policies"
    name      = "ConnectionDrainingEnabled"
    value     = "true"
  }
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "AccessLogsS3Bucket"
    value     = "${aws_s3_bucket.elb_logs.id}"
  }
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "AccessLogsS3Enabled"
    value     = "true"
  }
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "SecurityGroups"
    value     = "${join(",", var.loadbalancer_security_groups)}"
  }
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "ManagedSecurityGroup"
    value     = "${var.loadbalancer_managed_security_group}"
  }
  setting {
    namespace = "aws:elbv2:listener:default"
    name      = "ListenerEnabled"
    value     = "${var.http_listener_enabled == "true" || var.loadbalancer_certificate_arn == "" ? "true" : "false"}"
  }
  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "ListenerEnabled"
    value     = "${var.loadbalancer_certificate_arn == "" ? "false" : "true"}"
  }
  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "Protocol"
    value     = "HTTPS"
  }
  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "SSLCertificateArns"
    value     = "${var.loadbalancer_certificate_arn}"
  }
  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "SSLPolicy"
    value     = "${var.loadbalancer_type == "application" ? var.loadbalancer_ssl_policy : ""}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "ConfigDocument"
    value     = "${var.config_document}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application"
    name      = "Application Healthcheck URL"
    value     = "HTTP:${var.application_port}${var.healthcheck_url}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "${var.environment_type}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "${var.loadbalancer_type}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = "${var.service_name == "" ? module.iam_roles.service_name : var.service_name}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "${var.enhanced_reporting_enabled ? "enhanced" : "basic"}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSizeType"
    value     = "Fixed"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSize"
    value     = "1"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "BASE_HOST"
    value     = "${var.name}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "CONFIG_SOURCE"
    value     = "${var.config_source}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "${var.enable_managed_actions ? "true" : "false"}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "PreferredStartTime"
    value     = "${var.preferred_start_time}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "${var.update_level}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "InstanceRefreshEnabled"
    value     = "${var.instance_refresh_enabled}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:container:nodejs"
    name      = "NodeVersion"
    value     = "${var.nodejs_version}"
  }
  ###===================== Application ENV vars ======================###
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "${element(keys(var.env_vars), 0)}"
    value     = "${lookup(var.env_vars, element(keys(var.env_vars), 0), "DEFAULT_VALUE")}"
  }
  ###===================== Application Load Balancer Health check settings =====================================================###
  # The Application Load Balancer health check does not take into account the Elastic Beanstalk health check path
  # http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/environments-cfg-applicationloadbalancer.html
  # http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/environments-cfg-applicationloadbalancer.html#alb-default-process.config
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckPath"
    value     = "${var.healthcheck_url}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "Port"
    value     = "${var.application_port}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "Protocol"
    value     = "HTTP"
  }
  ###===================== Load Balancer stickiness settings =====================================================###
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "StickinessEnabled"
    value     = "${var.stickiness_enabled}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "StickinessLBCookieDuration"
    value     = "${var.stickiness_lb_cookie_duration}"
  }
  # This should make it work with Classic Load balancer
  # https://github.com/terraform-providers/terraform-provider-aws/issues/4000
  setting {
    namespace = "aws:elb:policies"
    name      = "Stickiness Policy"
    value     = "${var.stickiness_enabled}"
  }
  setting {
    namespace = "aws:elb:policies"
    name      = "Stickiness Cookie Expiration"
    value     = "${var.stickiness_lb_cookie_duration}"
  }

  ###===================== Notification =====================================================###

  setting {
    namespace = "aws:elasticbeanstalk:sns:topics"
    name      = "Notification Endpoint"
    value     = "${var.notification_endpoint}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:sns:topics"
    name      = "Notification Protocol"
    value     = "${var.notification_protocol}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:sns:topics"
    name      = "Notification Topic ARN"
    value     = "${var.notification_topic_arn}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:sns:topics"
    name      = "Notification Topic Name"
    value     = "${var.notification_topic_name}"
  }
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "elb_logs" {
  statement {
    sid = ""

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${module.label.id}-logs/*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["${data.aws_elb_service_account.main.arn}"]
    }

    effect = "Allow"
  }
}

resource "aws_s3_bucket" "elb_logs" {
  bucket        = "${module.label.id}-logs"
  acl           = "private"
  force_destroy = "${var.force_destroy}"
  policy        = "${data.aws_iam_policy_document.elb_logs.json}"
}

module "tld" {
  source    = "git::https://github.com/cloudposse/terraform-aws-route53-cluster-hostname.git?ref=tags/0.2.5"
  namespace = "${var.namespace}"
  name      = "${var.name}"
  stage     = "${var.stage}"
  zone_id   = "${var.zone_id}"
  records   = ["${aws_elastic_beanstalk_environment.default.cname}"]
  enabled   = "${length(var.zone_id) > 0 ? "true" : "false"}"
}
