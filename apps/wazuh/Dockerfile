FROM wazuh/wazuh-manager:4.14.5@sha256:3b2b7aae2daf696071ecc8b32a5d1e65e5c2a625291afc434bd20171a9d41109

# Install jq for custom-ntfy integration script
# Note: The initContainer approach in statefulset-manager.yaml is preferred
# for GitOps deployments. Use this Dockerfile only if you need a custom image.
USER root
RUN yum install -y jq && \
    yum clean all && \
    rm -rf /var/cache/yum
