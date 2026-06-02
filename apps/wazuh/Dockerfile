FROM wazuh/wazuh-manager:4.14.5@sha256:9eca1f6483e7ecf53c3a00524cee8f491afe6d26d724b71064b82191ea157e99

# Install jq for custom-ntfy integration script
# Note: The initContainer approach in statefulset-manager.yaml is preferred
# for GitOps deployments. Use this Dockerfile only if you need a custom image.
USER root
RUN yum install -y jq && \
    yum clean all && \
    rm -rf /var/cache/yum
