FROM wazuh/wazuh-manager:4.14.0

# Install jq for custom-ntfy integration script
# Note: The initContainer approach in statefulset-manager.yaml is preferred
# for GitOps deployments. Use this Dockerfile only if you need a custom image.
USER root
RUN yum install -y jq && \
    yum clean all && \
    rm -rf /var/cache/yum
