# Provision an EKS cluster

This repo is based on https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
Hashicorp provides a great Terraform boilerplate for EKS that can be modified to suit any requirement.

# Setting up for your own AWS provider

1. Fork/copy repository into your account or your organizations account.
2. In AWS console: Create IAM user (or use existing) for service with adequate permissions see https://docs.aws.amazon.com/eks/latest/userguide/security_iam_id-based-policy-examples.html
3. Save AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to Github Action's Secrets on the new repository

# Rename resources
    
Go through main.tf and rename resources as appropriate to your organization. This template was built for XYZ.

# Git flow

After any changes have been made on the edge branch (or feature branch then merged to edge) push or merge to edge
to launch the edge pipeline

Once the deployment is verified, this code can be pushed up into stable by creating a PR

Upon merging to stable, the pipeline to deploy the stable cluster will run

To deploy the production, create a tag from the main branch

# Sync kubeconfig to local machine

This is one way to manage resources from your own CLI and interact with the cluster

Install kubectl and AWS CLI and execute command:
    
    aws eks --region us-east-1 update-kubeconfig --name name-of-your-cluster

# Verify deployment

Once kubectl is synced with the EKS cluster, we can check to see the services running in the different namespaces:
    - kubectl get namespace
    - kubectl get services --all-namespaces
    - kubectl get pods --all-namespaces

# Deploy application to cluster
There won't be any services on the cluster initially, but there are instructions and a template to deploy services to this cluster
that can be found here: https://github.com/NathanaelG1/eks-typescript-app-template

# Destroy cluster
There is a destroy cluster job on the Actions tab that can be optionally run with arguments: edge, stable, or production
Run this github action in order to destroy a cluster. Dont worry, it can be spun back up!