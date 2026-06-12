FROM wazuh/wazuh-manager:4.14.5@sha256:824ff13d446682cd3bd5960479ce0d1d6a9fed8fdbc0ce31a4f0f3b9a97a7734

# Install jq for custom-ntfy integration script
# Note: The initContainer approach in statefulset-manager.yaml is preferred
# for GitOps deployments. Use this Dockerfile only if you need a custom image.
USER root
RUN yum install -y jq && \
    yum clean all && \
    rm -rf /var/cache/yum
