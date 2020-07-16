provider "aws" {
  region     = "ap-south-1"
  profile    = "patask"
}

resource "aws_security_group" "securitygrp" {
  name        = "securitygrp"
  description = "create a security group & allow port number 80"
  vpc_id      = "vpc-eb938e83"
 ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "task" {
  ami           = " ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  subnet_id = "subnet-b81972f4"
  key_name      =  "MyKey1"
  security_groups = ["${aws_security_group.securitygrp.id}"]
  tags = {
    Name = "taskos"
  }
}


resource "aws_efs_file_system"  "efsfile"{
	creation_token="my-product"
  tags={
       Name= "my-product"
 }
}

resource "aws_efs_mount_target"  "efsvol"{
  file_system_id= aws_efs_file_system.efsfile.id
   subnet_id = "subnet-b81972f4"
   security_groups = ["${aws_security_group.securitygrp.id}"]
}

resource "null_resource" "volume" {
  depends_on = [
    aws_efs_mount_target.efsvol
  ]
connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Arti/Downloads/MyKey1.pem")
    host     = aws_instance.task.public_ip
  }


provisioner "remote-exec"{
   
       inline = [
         
          "sudo yum install httpd php git -y",
	  "sudo systemctl start httpd",
	  "sudo systemctl enable httpd",
          "sudo mkfs.ext4  /dev/xvdf",
          "sudo rm -rf /var/www/html/*",
          "sudo mount  /dev/xvdf  /var/www/html",
          "sudo git clone https://github.com/aartisharma-pa/Cloud-Task.git /var/www/html/",
	  "sudo rm -rf /var/www/html/"
         ]
    }
}


resource "aws_s3_bucket" "s3bucket" {
    
 depends_on = [
   aws_efs_mount_target.efsvol
  ]

  bucket = "bucket0410"
  acl    = "public-read"
  force_destroy = true

 provisioner "local-exec" {
     command = "git clone https://github.com/aartisharma-pa/Cloud-Task.git C:/Users/Arti/Desktop/terra/finaltask/Git"
      }
}

resource "aws_s3_bucket_object" "s3object" {

  depends_on= [aws_s3_bucket.s3bucket]
  bucket = aws_s3_bucket.s3bucket.bucket
  force_destroy = true
  key    = "img.jpg"
  source = "C:/Users/Arti/Desktop/terra/finaltask/Git/img.jpg"
  content_type = "image/jpg"
  acl = "public-read"
 }


resource "aws_cloudfront_distribution" "cloudfront" {

	origin {
		domain_name = aws_s3_bucket.s3bucket.bucket_regional_domain_name
		origin_id   = "aws_s3_bucket.s3bucket.bucket.s3_origin_id"


		custom_origin_config {
			http_port = 80
			https_port = 80
			origin_protocol_policy = "match-viewer"
			origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
		}
	}

	enabled = true

	default_cache_behavior {
		allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
		cached_methods = ["GET", "HEAD"]
		target_origin_id = "aws_s3_bucket.s3bucket.bucket.s3_origin_id"

		forwarded_values {
			query_string = false

			cookies {
				forward = "none"
			}
		}
		viewer_protocol_policy = "allow-all"
		min_ttl = 0
		default_ttl = 3600
		max_ttl = 86400
	}

	restrictions {
		geo_restriction {

			restriction_type = "none"
		}
	}

	viewer_certificate {
		cloudfront_default_certificate = true
	}
}


resource "null_resource" "finalnull"  {


depends_on = [
      aws_cloudfront_distribution.cloudfront,
  ]

	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.task.public_ip}"
  	}
}

