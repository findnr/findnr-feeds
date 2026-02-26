'use strict';
'require ui';
'require view';

return view.extend({
    render: function () {
        var form = document.querySelector('form');
        var btn = document.querySelector('input[type="submit"], button[type="submit"]') || document.querySelector('button');

        // === 1. Error Handling (Universal) ===
        if (window.location.search.indexOf('simple2fa_err=1') !== -1) {
            var errDiv = document.createElement('div');
            // Try different error classes for compatibility
            errDiv.className = 'alert-message error cbi-section-error alert alert-danger';
            errDiv.innerText = _('Authentication Failed: Invalid 2FA Code');
            errDiv.style.marginBottom = '10px';
            errDiv.style.textAlign = 'center';

            // Insert at the very top of the form or container
            if (form) {
                form.insertBefore(errDiv, form.firstChild);
            }

            // Cleanup URL
            if (history.replaceState) {
                var newUrl = window.location.protocol + "//" + window.location.host + window.location.pathname;
                history.replaceState({ path: newUrl }, '', newUrl);
            }
        }

        // === 2. Create the 2FA Token Field ===
        var tokenDiv = document.createElement('div');
        // 'cbi-value' is standard LuCI, but we add inline styles for safety
        tokenDiv.className = 'cbi-value field';
        tokenDiv.style.marginTop = '10px';

        tokenDiv.innerHTML = [
            '<label class="cbi-value-title" style="float:left; width:30%; padding-right:10px;">' + _('2FA Code') + '</label>',
            '<div class="cbi-value-field" style="float:left; width:70%;">',
            '  <input class="cbi-input-text" type="text" id="token_visible" placeholder="' + _('Leave empty if disabled') + '" autocomplete="off" style="width:100%;" />',
            '</div>',
            '<div style="clear:both;"></div>'
        ].join('');

        // === 3. Smart Insertion (Theme Compatibility) ===
        // To be compatible with Argon, Material, Bootstrap, and others, 
        // we should insert our token wrapper just before the submit button container,
        // rather than relying on assumed 'cbi-value' parent chains of the password input.
        if (btn && form) {
            // Find a suitable container to insert before the button
            var insertionPoint = btn;
            // Climb up a bit to find the wrapper div of the button if it exists
            if (btn.parentElement && btn.parentElement.tagName === 'DIV' && btn.parentElement !== form) {
                insertionPoint = btn.parentElement;
                // Climb one more level if it's deeply nested (e.g. cbi-value-field -> cbi-value)
                if (insertionPoint.parentElement && insertionPoint.parentElement.tagName === 'DIV' && insertionPoint.parentElement !== form) {
                     insertionPoint = insertionPoint.parentElement;
                }
            }
            
            // Apply neutral styling so it doesn't break Flex/Grid layouts
            tokenDiv.className = '';
            tokenDiv.style.margin = '15px 0';
            tokenDiv.style.width = '100%';
            
            tokenDiv.innerHTML = [
                '<div style="display:flex; flex-direction:column; gap:5px;">',
                '  <label style="font-weight:bold; color:inherit;">' + _('2FA Code') + '</label>',
                '  <input class="cbi-input-text input" type="text" id="token_visible" placeholder="' + _('Leave empty if disabled') + '" autocomplete="off" style="width:100%; box-sizing:border-box; padding:8px; border:1px solid rgba(0,0,0,0.2); border-radius:4px;" />',
                '</div>'
            ].join('');

            insertionPoint.parentNode.insertBefore(tokenDiv, insertionPoint);
        } else {
            // Fallback: Append to form
            if (form) form.appendChild(tokenDiv);
        }

        // === 4. Submit Handler (Inject Hidden Field) ===
        if (btn && form) {
            // Function to handle the injection
            var injectAndSubmit = function (e) {
                var visibleInput = document.getElementById('token_visible');
                var val = visibleInput ? visibleInput.value.trim() : '';

                // Create hidden input for the actual POST
                var hiddenInput = document.createElement('input');
                hiddenInput.type = 'hidden';
                hiddenInput.name = 'token'; // Must match Lua CGI
                hiddenInput.value = val;
                form.appendChild(hiddenInput);

                // Show loading state
                if (window.ui && ui.showModal) {
                    // Use LuCI's native modal only if sure, otherwise just change button text
                    // ui.showModal(_('Logging in...'), [E('p', {class: 'spinning'}, _('Verifying...'))]);
                }
                var btnTxt = btn.value || btn.innerText;
                if (btn.tagName === 'INPUT') btn.value = _('Verifying...');
                else btn.innerText = _('Verifying...');
            };

            // Listen for click
            btn.addEventListener('click', injectAndSubmit);

            // Listen for Enter key on inputs
            form.addEventListener('keypress', function (e) {
                if (e.key === 'Enter') {
                    injectAndSubmit();
                    // Let the form submit naturally, just ensure the listener ran first
                }
            });
        }

        // Auto-focus password if present
        var passInput = document.querySelector('input[type="password"]');
        if (passInput) passInput.focus();

        return '';
    },

    addFooter: function () { }
});
