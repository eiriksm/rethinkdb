# Copyright 2010-2012 RethinkDB, all rights reserved.

# This file extends the UIComponents module with commonly used modal
# dialog boxes.
module 'UIComponents', ->
    # Modal that allows for form submission
    class @AbstractModal extends Backbone.View
        template_outer: Handlebars.templates['abstract-modal-outer-template']
        error_template: Handlebars.templates['error_input-template']

        events:
            'click .cancel': 'cancel_modal'
            'click .close_modal': 'cancel_modal'
            'click .btn-primary': 'abstract_submit'
            'keypress input': 'check_keypress_is_enter'
            'click .alert .close': 'close_error'

        close_error: (event) ->
            event.preventDefault()
            $(event.currentTarget).parent().slideUp('fast', -> $(this).remove())


        initialize: ->
            @$container = $('#modal-dialog')
            @custom_buttons = []

        # Render and show the modal.
        #   validator_options: object that defines form behavior and validation rules
        #   template_json: json to pass to the template for the modal
        render: (template_data) =>

            # Add the modal generated from the template to the container, and show it
            template_data = {} if not template_data?
            template_data = _.extend template_data,
                modal_class: @class
            @$container.html @template_outer template_data
            $('.modal-body', @$container).html @template template_data

            # Note: Bootstrap's modal JS moves the modal from the container element to the end of the body tag in the DOM
            @$modal = $('.modal', @$container).modal
                'show': true
                'backdrop': true
                'keyboard': true
            .on 'hidden', =>
                # Removes the modal dialog from the DOM
                @$modal.remove()

            # Define @el to be the modal (the root of the view), make sure events perform on it
            @.setElement @$modal
            @.delegateEvents()

            for btn in @custom_buttons
                @.$('.custom_btn_placeholder').append("<button class='btn #{ btn.class_str }' data-loading-text='#{ btn.data_loading_text }'>#{ btn.main_text }</button>")
                @.$('.custom_btn_placeholder > .' + btn.class_str).click (e) =>
                    btn.on_click(e)
                @.$('.custom_btn_placeholder > .' + btn.class_str).button()

            register_modal @

        hide_modal: =>
            @$modal.modal('hide') if @$modal?
            @destroy()

        cancel_modal: (e) ->
            @.hide_modal()
            e.preventDefault()

        check_keypress_is_enter: (event) =>
            if event.which is 13
                event.preventDefault()
                @abstract_submit(event)

        abstract_submit: (event) ->
            event.preventDefault()
            @on_submit(event)

        reset_buttons: =>
            @.$('.btn-primary').button('reset')
            @.$('.cancel').button('reset')

        # This is meant to be called by the overriding class
        on_success: (response) =>
            @reset_buttons()
            clear_modals()

        on_submit: (event) =>
            @.$('.btn-primary').button('loading')
            @.$('.cancel').button('loading')

        on_error: (error) =>
            @.$('.alert_modal').html @error_template
                ajax_fail: true
                error: (error if error? and error isnt '')

            if @.$('.alert_modal_content').css('display') is 'none'
                @.$('.alert_modal_content').slideDown('fast')
            else
                @.$('.alert_modal_content').css('display', 'none')
                @.$('.alert_modal_content').fadeIn()
            @reset_buttons()

        add_custom_button: (main_text, class_str, data_loading_text, on_click) =>
            @custom_buttons.push
                main_text: main_text
                class_str: class_str
                data_loading_text: data_loading_text
                on_click: on_click

        find_custom_button: (class_str) =>
            return @.$('.custom_btn_placeholder > .' + class_str)

    # This is for doing user confirmation easily
    class @ConfirmationDialogModal extends @AbstractModal
        template: Handlebars.templates['confirmation_dialog-template']
        class: 'confirmation-modal'

        initialize: ->
            log_initial '(initializing) modal dialog: confirmation'
            super

        render: (message, _url, _data, _on_success) ->
            log_render '(rendering) add secondary dialog'
            @url = _url
            @data = _data
            @on_user_success = _on_success

            super
                message: message
                modal_title: 'Confirmation'
                btn_secondary_text: 'No'
                btn_primary_text: 'Yes'
            @.$('.btn-primary').focus()

        on_submit: ->
            super
            $.ajax
                processData: false
                url: @url
                type: 'POST'
                contentType: 'application/json'
                data: @data
                success: @on_success
                error: @on_error

        on_success: (response) ->
            super
            @on_user_success(response)

    # Rename common items (namespaces, machines, datacenters)
    # The modal takes a few arguments:
    #   - item_uuid: uuid of the element to rename
    #   - item_type: type of the element to rename
    #   - on_success: function to perform on successful rename
    #   - options:
    #     * hide_alert: hide the alert shown in the user space on success
    class @RenameItemModal extends @AbstractModal
        template: Handlebars.templates['rename_item-modal-template']
        alert_tmpl: Handlebars.templates['renamed_item-alert-template']
        error_template: Handlebars.templates['error_input-template']
        class: 'rename-item-modal'

        initialize: (uuid, type, on_success, options) ->
            log_initial '(initializing) modal dialog: rename item'
            @item_uuid = uuid
            @item_type = type
            @user_on_success = on_success
            @options = options
            super

        get_item_object: ->
            switch @item_type
                when 'datacenter' then return datacenters.get(@item_uuid)
                when 'table' then return namespaces.get(@item_uuid)
                when 'server' then return machines.get(@item_uuid)
                when 'database' then return databases.get(@item_uuid)
                else return null

        get_item_url: ->
            switch @item_type
                when 'datacenter' then return 'datacenters'
                when 'table' then return namespaces.get(@item_uuid).get('protocol') + '_namespaces'
                when 'server' then return 'machines'
                when 'database' then return 'databases'
                else return null

        render: ->
            log_render '(rendering) rename item dialog'

            super
                type: @item_type
                old_name: @get_item_object().get('name')
                modal_title: 'Rename ' + @item_type
                btn_primary_text: 'Rename'

            $('#focus_new_name').focus()
            

        on_submit: ->
            super
            @old_name = @get_item_object().get('name')
            @formdata = form_data_as_object($('form', @$modal))

            no_error = true
            if @item_type is 'namespace'
                if @formdata.new_name is ''
                    no_error = false
                    $('.alert_modal').html @error_template
                        namespace_is_empty: true
                else if /^[a-zA-Z0-9_]+$/.test(@formdata.new_name) is false
                    no_error = false
                    $('.alert_modal').html @error_template
                        special_char_detected: true
                        type: 'table'
                else
                    for namespace in namespaces.models
                        if namespace.get('name') is @formdata.new_name and namespace.get('database') is @model.get('database')
                            no_error = false
                            $('.alert_modal').html @error_template
                                namespace_exists: true
                            break

            if @item_type is 'database'
                if @formdata.new_name is ''
                    no_error = false
                    $('.alert_modal').html @error_template
                        database_is_empty: true
                else if /^[a-zA-Z0-9_]+$/.test(@formdata.new_name) is false
                    no_error = false
                    $('.alert_modal').html @error_template
                        special_char_detected: true
                        type: 'database'
                else
                    for database in databases.models
                        if database.get('name') is @formdata.new_name
                            no_error = false
                            $('.alert_modal').html @error_template
                                database_exists: true
                            break

            if @item_type is 'datacenter'
                if @formdata.new_name is ''
                    no_error = false
                    $('.alert_modal').html @error_template
                        datacenter_is_empty: true
                else if /^[a-zA-Z0-9_]+$/.test(@formdata.new_name) is false
                    no_error = false
                    $('.alert_modal').html @error_template
                        special_char_detected: true
                        type: 'datacenter'
                else
                    for datacenter in datacenters.models
                        if datacenter.get('name').toLowerCase() is @formdata.new_name.toLowerCase()
                            no_error = false
                            $('.alert_modal').html @error_template
                                datacenter_exists: true
                            break

            if @item_type is 'machine'
                if @formdata.new_name is ''
                    no_error = false
                    $('.alert_modal').html @error_template
                        machine_is_empty: true
                else if /^[a-zA-Z0-9_]+$/.test(@formdata.new_name) is false
                    no_error = false
                    $('.alert_modal').html @error_template
                        special_char_detected: true
                        type: 'server'
                else
                    for machine in machines.models
                        if machine.get('name').toLowerCase() is @formdata.new_name.toLowerCase()
                            no_error = false
                            template_error =
                                machine_exists: true
                            $('.alert_modal').html @error_template template_error
                            break

            if no_error is true
                $.ajax
                    processData: false
                    url: "/ajax/semilattice/" + @get_item_url() + "/#{@item_uuid}/name"
                    type: 'POST'
                    contentType: 'application/json'
                    data: JSON.stringify(@formdata.new_name)
                    success: @on_success
                    error: @on_error
            else
                $('.alert_modal_content').slideDown 'fast'
                @reset_buttons()

        on_success: (response) ->
            super
            # update proper model with the name
            @get_item_object().set('name', @formdata.new_name)

            # Unless an alerts should be suppressed, show an alert
            if @options and not @options.hide_alert
                # notify the user that we succeeded
                $('#user-alert-space').html @alert_tmpl
                    type: @item_type
                    old_name: @old_name
                    new_name: @formdata.new_name

            # Call custom success function
            if @user_on_success?
                @user_on_success response

