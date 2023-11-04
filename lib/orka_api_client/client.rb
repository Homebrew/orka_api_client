# frozen_string_literal: true

require_relative "errors"
require_relative "connection"
require_relative "models/enumerator"
require_relative "models/user"
require_relative "models/vm_configuration"
require_relative "models/vm_resource"
require_relative "models/node"
require_relative "models/image"
require_relative "models/remote_image"
require_relative "models/iso"
require_relative "models/remote_iso"
require_relative "models/kube_account"
require_relative "models/log_entry"
require_relative "models/token_info"
require_relative "models/password_requirements"

module OrkaAPI
  # This is the entrypoint class for all interactions with the Orka API.
  class Client
    # Creates an instance of the client for a given Orka service endpoint and associated credentials.
    #
    # @param [String] base_url The API URL for the Orka service endpoint.
    # @param [String] token The token used for authentication. This can be generated with {#create_token} from an
    #   credentialless client.
    # @param [String] license_key The Orka license key used for authentication in administrative operations.
    def initialize(base_url, token: nil, license_key: nil)
      @conn = Connection.new(base_url, token: token, license_key: license_key)
      @license_key = license_key
    end

    # @!macro [new] lazy_enumerator
    #   The network operation is not performed immediately upon return of this method. The request is performed when
    #   any action is performed on the enumerator, or otherwise forced via {Models::Enumerator#eager}.

    # @!macro [new] lazy_object
    #   The network operation is not performed immediately upon return of this method. The request is performed when
    #   any attribute is accessed or any method is called on the returned object, or otherwise forced via
    #   {Models::LazyModel#eager}. Successful return from this method does not guarantee the requested resource
    #   exists.

    # @!macro [new] auth_none
    #   This method does not require the client to be configured with any credentials.

    # @!macro [new] auth_token
    #   This method requires the client to be configured with a token.

    # @!macro [new] auth_license
    #   This method requires the client to be configured with a license key.

    # @!macro [new] auth_token_and_license
    #   This method requires the client to be configured with both a token and a license key.

    # @!group Users

    # Retrieve a list of the users in the Orka environment.
    #
    # @macro auth_license
    #
    # @macro lazy_enumerator
    #
    # @return [Models::Enumerator<Models::User>] The enumerator of the user list.
    def users
      Models::Enumerator.new do
        users = []
        body = @conn.get("users") do |r|
          r.options.context = {
            orka_auth_type: :license,
          }
        end.body
        groups = body["user_groups"]
        if groups.nil?
          user_list = body["user_list"]
          user_list.each do |user|
            users << Models::User.new(
              conn:  @conn,
              email: user,
              group: "$ungrouped",
            )
          end
        else
          groups.each do |group, group_users|
            group_users.each do |group_user|
              users << Models::User.new(
                conn:  @conn,
                email: group_user,
                group: group,
              )
            end
          end
        end
        users
      end
    end

    # Fetches information on a particular user in the Orka environment.
    #
    # @macro auth_license
    #
    # @macro lazy_object
    #
    # @param [String] email The email of the user to fetch.
    # @return [Models::User] The lazily-loaded user object.
    def user(email)
      Models::User.lazy_prepare(email: email, conn: @conn)
    end

    # Create a new user in the Orka environment. You need to specify email address and password. You cannot pass an
    # email address that's already in use.
    #
    # @macro auth_license
    #
    # @param [String] email An email address for the user. This also serves as the username.
    # @param [String] password A password for the user. Must be at least 6 characters long.
    # @param [String] group A user group for the user. Once set, you can no longer change the user group.
    # @return [Models::User] The user object.
    def create_user(email:, password:, group: nil)
      body = {
        email:    email,
        password: password,
        group:    group,
      }.compact
      @conn.post("users", body) do |r|
        r.options.context = {
          orka_auth_type: :license,
        }
      end

      group = "$ungrouped" if group.nil?
      Models::User.new(conn: @conn, email: email, group: group)
    end

    # Modify the email address or password of the current user. This operation is intended for regular Orka users.
    #
    # @macro auth_token
    #
    # @param [String] email The new email address for the user.
    # @param [String] password The new password for the user.
    # @return [void]
    def update_user_credentials(email: nil, password: nil)
      raise ArgumentError, "Must update either the username or password, or both." if email.nil? && password.nil?

      body = {
        email:    email,
        password: password,
      }.compact
      @conn.put("users", body) do |r|
        r.options.context = {
          orka_auth_type: :token,
        }
      end
    end

    # @!endgroup
    # @!group Tokens

    # Create an authentication token using an existing user's email and password.
    #
    # @macro auth_none
    #
    # @param [Models::User, String] user The user or their associated email address.
    # @param [String] password The user's password.
    # @return [String] The authentication token.
    def create_token(user:, password:)
      body = {
        email:    user_email(user),
        password: password,
      }.compact
      @conn.post("token", body).body["token"]
    end

    # Revoke the token associated with this client instance.
    #
    # @macro auth_token
    #
    # @return [void]
    def revoke_token
      @conn.delete("token") do |r|
        r.options.context = {
          orka_auth_type: :token,
        }
      end
    end

    # @!endgroup
    # @!group VMs

    # Retrieve a list of the VMs and VM configurations. By default this fetches resources associated with the
    # client's token, but you can optionally request a list of resources for another user (or all users).
    #
    # If you filter by a user, or request all users, this method requires the client to be configured with both a
    # token and a license key. Otherwise, it only requires a token.
    #
    # @macro lazy_enumerator
    #
    # @param [Models::User, String] user The user, or their associated email address, to use instead of the one
    #   associated with the client's token. Pass "all" if you wish to fetch for all users.
    # @return [Models::Enumerator<Models::VMResource>] The enumerator of the VM resource list.
    def vm_resources(user: nil)
      Models::Enumerator.new do
        url = "resources/vm/list"
        url += "/#{user}" unless user.nil?
        resources = @conn.get(url, { expand: nil }) do |r|
          auth_type = [:token]
          auth_type << :license unless user.nil?
          r.options.context = {
            orka_auth_type: auth_type,
          }
        end.body["virtual_machine_resources"]
        resources.map { |hash| Models::VMResource.from_hash(hash, conn: @conn, admin: !user.nil?) }
      end
    end

    # Fetches information on a particular VM or VM configuration.
    #
    # If you set the admin parameter to true, this method requires the client to be configured with both a
    # token and a license key. Otherwise, it only requires a token.
    #
    # @macro lazy_object
    #
    # @param [String] name The name of the VM resource to fetch.
    # @param [Boolean] admin Set to true to allow VM resources associated with other users to be queried.
    # @return [Models::VMResource] The lazily-loaded VM resource object.
    def vm_resource(name, admin: false)
      Models::VMResource.lazy_prepare(name: name, conn: @conn, admin: admin)
    end

    # Retrieve a list of the VM configurations associated with the client's token. Orka returns information about the
    # base image, CPU cores, owner and name of the VM configurations.
    #
    # @macro auth_token
    #
    # @macro lazy_enumerator
    #
    # @return [Models::Enumerator<Models::VMConfiguration>] The enumerator of the VM configuration list.
    def vm_configurations
      Models::Enumerator.new do
        configs = @conn.get("resources/vm/configs") do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end.body["configs"]
        configs.map { |hash| Models::VMConfiguration.from_hash(hash, conn: @conn) }
      end
    end

    # Fetches information on a particular VM configuration.
    #
    # @macro auth_token
    #
    # @macro lazy_object
    #
    # @param [String] name The name of the VM configuration to fetch.
    # @return [Models::VMConfiguration] The lazily-loaded VM configuration.
    def vm_configuration(name)
      Models::VMConfiguration.lazy_prepare(name: name, conn: @conn)
    end

    # Create a VM configuration that is ready for deployment. In Orka, VM configurations are container templates.
    # You can deploy multiple VMs from a single VM configuration. You cannot modify VM configurations.
    #
    # @macro auth_token
    #
    # @param [String] name The name of the VM configuration. This string must consist of lowercase Latin alphanumeric
    #   characters or the dash (+-+). This string must begin and end with an alphanumeric character. This string must
    #   not exceed 38 characters.
    # @param [Models::Image, String] base_image The name of the base image that you want to use with the
    #   configuration. If you want to attach an ISO to the VM configuration from which to install macOS, make sure
    #   that the base image is an empty disk of a sufficient size.
    # @param [Models::Image, String] snapshot_image A name for the
    #   {https://orkadocs.macstadium.com/docs/orka-glossary#section-snapshot-image snapshot image} of the VM.
    #   Typically, the same value as +name+.
    # @param [Integer] cpu_cores The number of CPU cores to dedicate for the VM. Must be 3, 4, 6, 8, 12, or 24.
    # @param [Integer] vcpu_count The number of vCPUs for the VM. Must equal the number of CPUs, when CPU is less
    #   than or equal to 3. Otherwise, must equal half of or exactly the number of CPUs specified.
    # @param [Models::ISO, String] iso_image An ISO to attach to the VM on deployment. The option is supported for
    #   VMs deployed on Intel nodes only.
    # @param [Models::Image, String] attached_disk An additional storage disk to attach to the VM on deployment. The
    #   option is supported for VMs deployed on Intel nodes only.
    # @param [Boolean] vnc_console By default, +true+. Enables or disables VNC for the VM configuration. You can
    #   override on deployment of specific VMs. The option is supported for VMs deployed on Intel nodes only.
    # @param [String] system_serial Assign an owned macOS system serial number to the VM configuration. The option is
    #   supported for VMs deployed on Intel nodes only.
    # @param [Boolean] io_boost By default, +false+ for VM configurations created before Orka 1.5. Default value for
    #   VM configurations created with Orka 1.5 or later depends on the cluster default. Enables or disables IO
    #   performance improvements for the VM configuration. The option is supported for VMs deployed on Intel nodes
    #   only.
    # @param [Boolean] gpu_passthrough Enables or disables GPU passthrough for the VM. When enabled, +vnc_console+ is
    #   automatically disabled. The option is supported for VMs deployed on Intel nodes only. GPU passthrough is an
    #   experimental feature. GPU passthrough must first be enabled in your cluster.
    # @param [String] tag When specified, the VM is preferred to be deployed to a node marked with this tag.
    # @param [Boolean] tag_required By default, +false+. When set to +true+, the VM is required to be deployed to a
    #   node marked with this tag.
    # @param [Symbol] scheduler Possible values are +:default+ and +:most-allocated+. By default, +:default+. When
    #   set to +:most-allocated+ VMs deployed from the VM configuration will be scheduled to nodes having most of
    #   their resources allocated. +:default+ keeps used vs free resources balanced between the nodes.
    # @return [Models::VMConfiguration] The lazily-loaded VM configuration.
    def create_vm_configuraton(name,
                               base_image:, snapshot_image:, cpu_cores:, vcpu_count:,
                               iso_image: nil, attached_disk: nil, vnc_console: nil,
                               system_serial: nil, io_boost: nil, gpu_passthrough: nil,
                               tag: nil, tag_required: nil, scheduler: nil)
      body = {
        orka_vm_name:    name,
        orka_base_image: base_image.is_a?(Models::Image) ? base_image.name : base_image,
        orka_image:      snapshot_image.is_a?(Models::Image) ? snapshot_image.name : snapshot_image,
        orka_cpu_core:   cpu_cores,
        vcpu_count:      vcpu_count,
        iso_image:       iso_image.is_a?(Models::ISO) ? iso_image.name : iso_image,
        attached_disk:   attached_disk.is_a?(Models::Image) ? attached_disk.name : attached_disk,
        vnc_console:     vnc_console,
        system_serial:   system_serial,
        io_boost:        io_boost,
        gpu_passthrough: gpu_passthrough,
        tag:             tag,
        tag_required:    tag_required,
        scheduler:       scheduler.to_s,
      }.compact
      @conn.post("resources/vm/create", body) do |r|
        r.options.context = {
          orka_auth_type: :token,
        }
      end
      vm_configuration(name)
    end

    # @!endgroup
    # @!group Nodes

    # Retrieve a list of the nodes in your Orka environment. Orka returns a list of nodes with IP and resource
    # information.
    #
    # If you set the admin parameter to true, this method requires the client to be configured with both a
    # token and a license key. Otherwise, it only requires a token.
    #
    # @macro lazy_enumerator
    #
    # @param [Boolean] admin Set to true to allow nodes dedicated to other users to be queried.
    # @return [Models::Enumerator<Models::Node>] The enumerator of the node list.
    def nodes(admin: false)
      Models::Enumerator.new do
        url = "resources/node/list"
        url += "/all" if admin
        nodes = @conn.get(url) do |r|
          auth_type = [:token]
          auth_type << :license if admin
          r.options.context = {
            orka_auth_type: auth_type,
          }
        end.body["nodes"]
        nodes.map { |hash| Models::Node.from_hash(hash, conn: @conn, admin: admin) }
      end
    end

    # Fetches information on a particular node.
    #
    # If you set the admin parameter to true, this method requires the client to be configured with both a
    # token and a license key. Otherwise, it only requires a token.
    #
    # @macro lazy_object
    #
    # @param [String] name The name of the node to fetch.
    # @param [Boolean] admin Set to true to allow nodes dedicated with other users to be queried.
    # @return [Models::VMResource] The lazily-loaded node object.
    def node(name, admin: false)
      Models::Node.lazy_prepare(name: name, conn: @conn, admin: admin)
    end

    # @!endgroup
    # @!group Images

    # Retrieve a list of the base images and empty disks in your Orka environment.
    #
    # @macro auth_token
    #
    # @macro lazy_enumerator
    #
    # @return [Models::Enumerator<Models::Image>] The enumerator of the image list.
    def images
      Models::Enumerator.new do
        images = @conn.get("resources/image/list") do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end.body["image_attributes"]
        images.map { |hash| Models::Image.from_hash(hash, conn: @conn) }
      end
    end

    # Fetches information on a particular image.
    #
    # @macro auth_token
    #
    # @macro lazy_object
    #
    # @param [String] name The name of the image to fetch.
    # @return [Models::Image] The lazily-loaded image.
    def image(name)
      Models::Image.lazy_prepare(name: name, conn: @conn)
    end

    # List the base images available in the Orka remote repo.
    #
    # To use one of the images from the remote repo, you can {Models::RemoteImage#pull pull} it into the local Orka
    # storage.
    #
    # @macro auth_token
    #
    # @macro lazy_enumerator
    #
    # @return [Models::Enumerator<Models::RemoteImage>] The enumerator of the remote image list.
    def remote_images
      Models::Enumerator.new do
        images = @conn.get("resources/image/list-remote") do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end.body["images"]
        images.map { |name| Models::RemoteImage.new(name, conn: @conn) }
      end
    end

    # Returns an object representing a remote image of a specified name.
    #
    # Note that this method does not perform any network requests and does not verify if the name supplied actually
    # exists in the Orka remote repo.
    #
    # @param [String] name The name of the remote image.
    # @return [Models::RemoteImage] The remote image object.
    def remote_image(name)
      Models::RemoteImage.new(name, conn: @conn)
    end

    # Generate an empty base image. You can use it to create VM configurations that will use an ISO or you can attach
    # it to a deployed VM to extend its storage.
    #
    # @macro auth_token
    #
    # @note This request is supported for Intel images only. Intel images have +.img+ extension.
    #
    # @param [String] name The name of this new image.
    # @param [String] size The size of this new image (in K, M, G, or T), for example +"10G"+.
    # @return [Models::Image] The new lazily-loaded image.
    def generate_empty_image(name, size:)
      body = {
        file_name: name,
        file_size: size,
      }.compact
      @conn.post("resources/image/generate", body) do |r|
        r.options.context = {
          orka_auth_type: :token,
        }
      end
      image(name)
    end

    # Upload an image to the Orka environment.
    #
    # @macro auth_token
    #
    # @note This request is supported for Intel images only. Intel images have +.img+ extension.
    #
    # @param [String, IO] file The string file path or an open IO object to the image to upload.
    # @param [String] name The name to give to this image. Defaults to the local filename.
    # @return [Models::Image] The new lazily-loaded image.
    def upload_image(file, name: nil)
      file_part = Faraday::Multipart::FilePart.new(
        file,
        "application/x-iso9660-image",
        name,
      )
      body = { image: file_part }
      @conn.post("resources/image/upload", body, "Content-Type" => "multipart/form-data") do |r|
        r.options.context = {
          orka_auth_type: :token,
        }
      end
      image(file_part.original_filename)
    end

    # @!endgroup
    # @!group ISOs

    # Retrieve a list of the ISOs available in the local Orka storage.
    #
    # @macro auth_token
    #
    # @macro lazy_enumerator
    #
    # @return [Models::Enumerator<Models::ISO>] The enumerator of the ISO list.
    def isos
      Models::Enumerator.new do
        isos = @conn.get("resources/iso/list") do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end.body["iso_attributes"]
        isos.map { |hash| Models::ISO.from_hash(hash, conn: @conn) }
      end
    end

    # Fetches information on a particular ISO in local Orka storage.
    #
    # @macro auth_token
    #
    # @macro lazy_object
    #
    # @param [String] name The name of the ISO to fetch.
    # @return [Models::ISO] The lazily-loaded ISO.
    def iso(name)
      Models::ISO.lazy_prepare(name: name, conn: @conn)
    end

    # List the ISOs available in the Orka remote repo.
    #
    # To use one of the ISOs from the remote repo, you can {Models::RemoteISO#pull pull} it into the local Orka
    # storage.
    #
    # @macro auth_token
    #
    # @macro lazy_enumerator
    #
    # @return [Models::Enumerator<Models::RemoteISO>] The enumerator of the remote ISO list.
    def remote_isos
      Models::Enumerator.new do
        isos = @conn.get("resources/iso/list-remote") do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end.body["isos"]
        isos.map { |name| Models::RemoteISO.new(name, conn: @conn) }
      end
    end

    # Returns an object representing a remote ISO of a specified name.
    #
    # Note that this method does not perform any network requests and does not verify if the name supplied actually
    # exists in the Orka remote repo.
    #
    # @param [String] name The name of the remote ISO.
    # @return [Models::RemoteISO] The remote ISO object.
    def remote_iso(name)
      Models::RemoteISO.new(name, conn: @conn)
    end

    # Upload an ISO to the Orka environment.
    #
    # @macro auth_token
    #
    # @param [String, IO] file The string file path or an open IO object to the ISO to upload.
    # @param [String] name The name to give to this ISO. Defaults to the local filename.
    # @return [Models::ISO] The new lazily-loaded ISO.
    def upload_iso(file, name: nil)
      file_part = Faraday::Multipart::FilePart.new(
        file,
        "application/x-iso9660-image",
        name,
      )
      body = { iso: file_part }
      @conn.post("resources/iso/upload", body, "Content-Type" => "multipart/form-data") do |r|
        r.options.context = {
          orka_auth_type: :token,
        }
      end
      iso(file_part.original_filename)
    end

    # @!endgroup
    # @!group Kube-Accounts

    # Retrieve a list of kube-accounts associated with an Orka user.
    #
    # @macro auth_token_and_license
    #
    # @macro lazy_enumerator
    #
    # @param [Models::User, String] user The user, which can be specified by the user object or their email address,
    #   for which we are returning the associated kube-accounts of. Defaults to the user associated with the client's
    #   token.
    # @return [Models::Enumerator<Models::KubeAccount>] The enumerator of the kube-account list.
    def kube_accounts(user: nil)
      Models::Enumerator.new do
        accounts = @conn.get("resources/kube-account") do |r|
          email = user_email(user)
          r.body = {
            email: email,
          }.compact

          r.options.context = {
            orka_auth_type: [:token, :license],
          }
        end.body["serviceAccounts"]
        accounts.map { |name| Models::KubeAccount.new(name, email: email, conn: @conn) }
      end
    end

    # Returns an object representing a kube-account of a particular user.
    #
    # Note that this method does not perform any network requests and does not verify if the name supplied actually
    # exists in the Orka environment.
    #
    # @param [String] name The name of the kube-account.
    # @param [Models::User, String] user The user, which can be specified by the user object or their email address,
    #   of which the kube-account is associated with. Defaults to the user associated with the client's token.
    # @return [Models::KubeAccount] The kube-account object.
    def kube_account(name, user: nil)
      Models::KubeAccount.new(name, email: user_email(user), conn: @conn)
    end

    # Create a kube-account.
    #
    # @macro auth_token_and_license
    #
    # @param [String] name The name of the kube-account.
    # @param [Models::User, String] user The user, which can be specified by the user object or their email address,
    #   of which the kube-account will be associated with. Defaults to the user associated with the client's token.
    # @return [Models::KubeAccount] The created kube-account.
    def create_kube_account(name, user: nil)
      email = user_email(user)
      body = {
        name:  name,
        email: email,
      }.compact
      kubeconfig = @conn.post("resources/kube-account", body) do |r|
        r.options.context = {
          orka_auth_type: [:token, :license],
        }
      end.body["kubeconfig"]
      Models::KubeAccount.new(name, email: email, kubeconfig: kubeconfig, conn: @conn)
    end

    # Delete all kube-accounts associated with a user.
    #
    # @macro auth_token_and_license
    #
    # @param [Models::User, String] user The user, which can be specified by the user object or their email address,
    #   which will have their associated kube-account deleted. Defaults to the user associated with the client's
    #   token.
    # @return [void]
    def delete_all_kube_accounts(user: nil)
      @conn.delete("resources/kube-account") do |r|
        email = user_email(user)
        r.body = {
          email: email,
        }.compact

        r.options.context = {
          orka_auth_type: [:token, :license],
        }
      end
    end

    # @!endgroup
    # @!group Logs

    # Retrieve a log of all CLI commands and API requests executed against your Orka environment.
    #
    # @macro auth_license
    #
    # @macro lazy_enumerator
    #
    # @param [Integer] limit Limit the amount of results returned to this amount.
    # @return [Models::Enumerator<Models::LogEntry>] The enumerator of the log entries list.
    def logs(limit: nil)
      Models::Enumerator.new do
        logs = @conn.post("logs/query") do |r|
          r.params[:limit] = limit unless limit.nil?

          r.options.context = {
            orka_auth_type: :license,
          }
        end.body["logs"]
        logs.map { |hash| Models::LogEntry.new(hash) }
      end
    end

    # Delete all logs for your Orka environment.
    #
    # @macro auth_token_and_license
    #
    # @return [void]
    def delete_logs
      @conn.delete("logs") do |r|
        r.options.context = {
          orka_auth_type: [:license, :token],
        }
      end
    end

    # @!endgroup
    # @!group Environment Checks

    # Retrieve information about the token associated with the client. The request returns information about the
    # associated email address, the authentication status of the token, and if the token is revoked.
    #
    # @macro auth_token
    #
    # @return [Models::TokenInfo] Information about the token.
    def token_info
      body = @conn.get("token") do |r|
        r.options.context = {
          orka_auth_type: :token,
        }
      end.body
      Models::TokenInfo.new(body, conn: @conn)
    end

    # Retrieve the current API version of your Orka environment.
    #
    # @macro auth_none
    #
    # @return [String] The remote API version.
    def remote_api_version
      @conn.get("health-check").body["api_version"]
    end

    # Retrieve the current password requirements for creating an Orka user.
    #
    # @macro auth_none
    #
    # @return [Models::PasswordRequirements] The password requirements.
    def password_requirements
      Models::PasswordRequirements.new(@conn.get("validation-requirements").body)
    end

    # Check if a license key is authorized or not.
    #
    # @macro auth_none
    #
    # @param [String] license_key The license key to check. Defaults to the one associated with the client.
    # @return [Boolean] True if the license key is valid.
    def license_key_valid?(license_key = @license_key)
      raise ArgumentError, "License key is required." if license_key.nil?

      @conn.get("validate-license-key") do |r|
        r.body = {
          licenseKey: license_key,
        }
      end
      true
    rescue Faraday::UnauthorizedError
      false
    end

    # Retrieve the default base image for the Orka environment.
    #
    # @macro auth_none
    #
    # @return [Models::Image] The lazily-loaded default base image object.
    def default_base_image
      Image.lazy_prepare(name: @conn.get("default-base-image").body["default_base_image"], conn: @conn)
    end

    # @!endgroup

    alias inspect to_s

    private

    def user_email(user)
      if user.is_a?(Models::User)
        user.email
      else
        user
      end
    end
  end
end
