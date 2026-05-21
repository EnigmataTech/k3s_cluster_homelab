FROM wazuh/wazuh-manager:4.14.5@sha256:d728ebe4a1b7d02d1216f937743f34d5827b61985aed8200ba5aace4b0f67022

# Install jq for custom-ntfy integration script
# Note: The initContainer approach in statefulset-manager.yaml is preferred
# for GitOps deployments. Use this Dockerfile only if you need a custom image.
USER root
RUN yum install -y jq && \
    yum clean all && \
    rm -rf /var/cache/yum
