#!/bin/bash
# Patch apllying tool template
# v0.1.2
# (c) Copyright 2013. Magento Inc.
#
# DO NOT CHANGE ANY LINE IN THIS FILE.

# 1. Check required system tools
_check_installed_tools() {
    local missed=""

    until [ -z "$1" ]; do
        type -t $1 >/dev/null 2>/dev/null
        if (( $? != 0 )); then
            missed="$missed $1"
        fi
        shift
    done

    echo $missed
}

REQUIRED_UTILS='sed patch'
MISSED_REQUIRED_TOOLS=`_check_installed_tools $REQUIRED_UTILS`
if (( `echo $MISSED_REQUIRED_TOOLS | wc -w` > 0 ));
then
    echo -e "Error! Some required system tools, that are utilized in this sh script, are not installed:\nTool(s) \"$MISSED_REQUIRED_TOOLS\" is(are) missed, please install it(them)."
    exit 1
fi

# 2. Determine bin path for system tools
CAT_BIN=`which cat`
PATCH_BIN=`which patch`
SED_BIN=`which sed`
PWD_BIN=`which pwd`
BASENAME_BIN=`which basename`

BASE_NAME=`$BASENAME_BIN "$0"`

# 3. Help menu
if [ "$1" = "-?" -o "$1" = "-h" -o "$1" = "--help" ]
then
    $CAT_BIN << EOFH
Usage: sh $BASE_NAME [--help] [-R|--revert] [--list]
Apply embedded patch.

-R, --revert    Revert previously applied embedded patch
--list          Show list of applied patches
--help          Show this help message
EOFH
    exit 0
fi

# 4. Get "revert" flag and "list applied patches" flag
REVERT_FLAG=
SHOW_APPLIED_LIST=0
if [ "$1" = "-R" -o "$1" = "--revert" ]
then
    REVERT_FLAG=-R
fi
if [ "$1" = "--list" ]
then
    SHOW_APPLIED_LIST=1
fi

# 5. File pathes
CURRENT_DIR=`$PWD_BIN`/
APP_ETC_DIR=`echo "$CURRENT_DIR""app/etc/"`
APPLIED_PATCHES_LIST_FILE=`echo "$APP_ETC_DIR""applied.patches.list"`

# 6. Show applied patches list if requested
if [ "$SHOW_APPLIED_LIST" -eq 1 ] ; then
    echo -e "Applied/reverted patches list:"
    if [ -e "$APPLIED_PATCHES_LIST_FILE" ]
    then
        if [ ! -r "$APPLIED_PATCHES_LIST_FILE" ]
        then
            echo "ERROR: \"$APPLIED_PATCHES_LIST_FILE\" must be readable so applied patches list can be shown."
            exit 1
        else
            $SED_BIN -n "/SUP-\|SUPEE-/p" $APPLIED_PATCHES_LIST_FILE
        fi
    else
        echo "<empty>"
    fi
    exit 0
fi

# 7. Check applied patches track file and its directory
_check_files() {
    if [ ! -e "$APP_ETC_DIR" ]
    then
        echo "ERROR: \"$APP_ETC_DIR\" must exist for proper tool work."
        exit 1
    fi

    if [ ! -w "$APP_ETC_DIR" ]
    then
        echo "ERROR: \"$APP_ETC_DIR\" must be writeable for proper tool work."
        exit 1
    fi

    if [ -e "$APPLIED_PATCHES_LIST_FILE" ]
    then
        if [ ! -w "$APPLIED_PATCHES_LIST_FILE" ]
        then
            echo "ERROR: \"$APPLIED_PATCHES_LIST_FILE\" must be writeable for proper tool work."
            exit 1
        fi
    fi
}

_check_files

# 8. Apply/revert patch
# Note: there is no need to check files permissions for files to be patched.
# "patch" tool will not modify any file if there is not enough permissions for all files to be modified.
# Get start points for additional information and patch data
SKIP_LINES=$((`$SED_BIN -n "/^__PATCHFILE_FOLLOWS__$/=" "$CURRENT_DIR""$BASE_NAME"` + 1))
ADDITIONAL_INFO_LINE=$(($SKIP_LINES - 3))p

_apply_revert_patch() {
    DRY_RUN_FLAG=
    if [ "$1" = "dry-run" ]
    then
        DRY_RUN_FLAG=" --dry-run"
        echo "Checking if patch can be applied/reverted successfully..."
    fi
    PATCH_APPLY_REVERT_RESULT=`$SED_BIN -e '1,/^__PATCHFILE_FOLLOWS__$/d' "$CURRENT_DIR""$BASE_NAME" | $PATCH_BIN $DRY_RUN_FLAG $REVERT_FLAG -p0`
    PATCH_APPLY_REVERT_STATUS=$?
    if [ $PATCH_APPLY_REVERT_STATUS -eq 1 ] ; then
        echo -e "ERROR: Patch can't be applied/reverted successfully.\n\n$PATCH_APPLY_REVERT_RESULT"
        exit 1
    fi
    if [ $PATCH_APPLY_REVERT_STATUS -eq 2 ] ; then
        echo -e "ERROR: Patch can't be applied/reverted successfully."
        exit 2
    fi
}

REVERTED_PATCH_MARK=
if [ -n "$REVERT_FLAG" ]
then
    REVERTED_PATCH_MARK=" | REVERTED"
fi

_apply_revert_patch dry-run
_apply_revert_patch

# 9. Track patch applying result
echo "Patch was applied/reverted successfully."
ADDITIONAL_INFO=`$SED_BIN -n ""$ADDITIONAL_INFO_LINE"" "$CURRENT_DIR""$BASE_NAME"`
APPLIED_REVERTED_ON_DATE=`date -u +"%F %T UTC"`
APPLIED_REVERTED_PATCH_INFO=`echo -n "$APPLIED_REVERTED_ON_DATE"" | ""$ADDITIONAL_INFO""$REVERTED_PATCH_MARK"`
echo -e "$APPLIED_REVERTED_PATCH_INFO\n$PATCH_APPLY_REVERT_RESULT\n\n" >> "$APPLIED_PATCHES_LIST_FILE"

exit 0


SUPEE-11086 | CE_1.6.2.0 | v1 | 0164cb9e3f81bcf0af7ac8bd4d12dda507dee6b5 | Thu Mar 21 21:15:53 2019 +0000 | 929f0fafeb464b3dadd9f5a19fb2422b0e9d1b9d..HEAD

__PATCHFILE_FOLLOWS__
diff --git app/Mage.php app/Mage.php
index 39c36d5462f..01f467ee91b 100644
--- app/Mage.php
+++ app/Mage.php
@@ -727,16 +727,22 @@ final class Mage
         static $loggers = array();
 
         $level  = is_null($level) ? Zend_Log::DEBUG : $level;
-        $file = empty($file) ? 'system.log' : basename($file);
+        $file = empty($file) ?
+            (string) self::getConfig()->getNode('dev/log/file', Mage_Core_Model_Store::DEFAULT_CODE) : basename($file);
 
         // Validate file extension before save. Allowed file extensions: log, txt, html, csv
-        if (!self::helper('log')->isLogFileExtensionValid($file)) {
+        $_allowedFileExtensions = explode(
+            ',',
+            (string) self::getConfig()->getNode('dev/log/allowedFileExtensions', Mage_Core_Model_Store::DEFAULT_CODE)
+        );
+        $logValidator = new Zend_Validate_File_Extension($_allowedFileExtensions);
+        $logDir = self::getBaseDir('var') . DS . 'log';
+        if (!$logValidator->isValid($logDir . DS . $file)) {
             return;
         }
 
         try {
             if (!isset($loggers[$file])) {
-                $logDir  = self::getBaseDir('var') . DS . 'log';
                 $logFile = $logDir . DS . $file;
 
                 if (!is_dir($logDir)) {
diff --git app/code/core/Enterprise/Staging/Helper/Store.php app/code/core/Enterprise/Staging/Helper/Store.php
index e9f894a73dd..a64cf04cbad 100644
--- app/code/core/Enterprise/Staging/Helper/Store.php
+++ app/code/core/Enterprise/Staging/Helper/Store.php
@@ -112,7 +112,9 @@ class Enterprise_Staging_Helper_Store extends Mage_Core_Helper_Url
             if (!preg_match('#^([0-9a-z_]+?)(_([0-9]+))?('.preg_quote($storeCodeSuffix).')?$#i', $code, $match)) {
                 return $this->getUnusedStoreCode('_');
             }
-            $code = $match[1].(isset($match[3])?'_'.($match[3]+1):'_1').(isset($match[4])?$match[4]:'');
+            $code = $match[1]
+                . (isset($match[3]) ? '_' . ((int) $match[3] + 1) : '_1')
+                . (isset($match[4]) ? $match[4] : '');
             return $this->getUnusedStoreCode($code);
         } else {
             return $code;
diff --git app/code/core/Enterprise/Staging/Helper/Website.php app/code/core/Enterprise/Staging/Helper/Website.php
index c2e02e7f79b..ecf8d327b13 100644
--- app/code/core/Enterprise/Staging/Helper/Website.php
+++ app/code/core/Enterprise/Staging/Helper/Website.php
@@ -112,7 +112,9 @@ class Enterprise_Staging_Helper_Website extends Mage_Core_Helper_Url
             if (!preg_match('#^([0-9a-z_]+?)(_([0-9]+))?('.preg_quote($websiteCodeSuffix).')?$#i', $code, $match)) {
                 return $this->getUnusedWebsiteCode('_');
             }
-            $code = $match[1].(isset($match[3])?'_'.($match[3]+1):'_1').(isset($match[4])?$match[4]:'');
+            $code = $match[1]
+                . (isset($match[3]) ? '_' . ((int) $match[3] + 1) : '_1')
+                . (isset($match[4]) ? $match[4] : '');
             return $this->getUnusedWebsiteCode($code);
         } else {
             return $code;
diff --git app/code/core/Mage/Admin/Model/Session.php app/code/core/Mage/Admin/Model/Session.php
index 2ba84803dde..fa886ec6884 100644
--- app/code/core/Mage/Admin/Model/Session.php
+++ app/code/core/Mage/Admin/Model/Session.php
@@ -158,15 +158,13 @@ class Mage_Admin_Model_Session extends Mage_Core_Model_Session_Abstract
             $e->setMessage(
                 Mage::helper('adminhtml')->__('You did not sign in correctly or your account is temporarily disabled.')
             );
-            Mage::dispatchEvent('admin_session_user_login_failed',
-                    array('user_name' => $username, 'exception' => $e));
-            if ($request && !$request->getParam('messageSent')) {
-                Mage::getSingleton('adminhtml/session')->addError($e->getMessage());
-                $request->setParam('messageSent', true);
-            }
+            $this->_loginFailed($e, $request, $username, $e->getMessage());
+        } catch (Exception $e) {
+            $message = Mage::helper('adminhtml')->__('An error occurred while logging in.');
+            $this->_loginFailed($e, $request, $username, $message);
         }
 
-        return $user;
+        return isset($user) ? $user : null;
     }
 
     /**
@@ -277,4 +275,29 @@ class Mage_Admin_Model_Session extends Mage_Core_Model_Session_Abstract
             return null;
         }
     }
+
+    /**
+     * Login failed process
+     *
+     * @param Exception $e
+     * @param string $username
+     * @param string $message
+     * @param Mage_Core_Controller_Request_Http $request
+     * @return void
+     */
+    protected function _loginFailed($e, $request, $username, $message)
+    {
+        try {
+            Mage::dispatchEvent('admin_session_user_login_failed', array(
+                'user_name' => $username,
+                'exception' => $e
+            ));
+        } catch (Exception $e) {
+        }
+
+        if ($request && !$request->getParam('messageSent')) {
+            Mage::getSingleton('adminhtml/session')->addError($message);
+            $request->setParam('messageSent', true);
+        }
+    }
 }
diff --git app/code/core/Mage/Adminhtml/Block/Api/Buttons.php app/code/core/Mage/Adminhtml/Block/Api/Buttons.php
index b76171b7236..cc105a373d7 100644
--- app/code/core/Mage/Adminhtml/Block/Api/Buttons.php
+++ app/code/core/Mage/Adminhtml/Block/Api/Buttons.php
@@ -65,7 +65,7 @@ class Mage_Adminhtml_Block_Api_Buttons extends Mage_Adminhtml_Block_Template
             $this->getLayout()->createBlock('adminhtml/widget_button')
                 ->setData(array(
                     'label'     => Mage::helper('adminhtml')->__('Delete Role'),
-                    'onclick'   => 'deleteConfirm(\'' . Mage::helper('adminhtml')->__('Are you sure you want to do this?') . '\', \'' . $this->getUrl('*/*/delete', array('rid' => $this->getRequest()->getParam('rid'))) . '\')',
+                    'onclick'   => 'deleteConfirm(\'' . Mage::helper('adminhtml')->__('Are you sure you want to do this?') . '\', \'' . $this->getUrlSecure('*/*/delete', array('rid' => $this->getRequest()->getParam('rid'))) . '\')',
                     'class' => 'delete'
                 ))
         );
diff --git app/code/core/Mage/Adminhtml/Block/Catalog/Product/Edit.php app/code/core/Mage/Adminhtml/Block/Catalog/Product/Edit.php
index 998b96adb58..229e3c5488d 100644
--- app/code/core/Mage/Adminhtml/Block/Catalog/Product/Edit.php
+++ app/code/core/Mage/Adminhtml/Block/Catalog/Product/Edit.php
@@ -199,7 +199,7 @@ class Mage_Adminhtml_Block_Catalog_Product_Edit extends Mage_Adminhtml_Block_Wid
 
     public function getDeleteUrl()
     {
-        return $this->getUrl('*/*/delete', array('_current'=>true));
+        return $this->getUrlSecure('*/*/delete', array('_current'=>true));
     }
 
     public function getDuplicateUrl()
diff --git app/code/core/Mage/Adminhtml/Block/Customer/Group/Edit.php app/code/core/Mage/Adminhtml/Block/Customer/Group/Edit.php
index 3852c23fc03..08018e498a9 100644
--- app/code/core/Mage/Adminhtml/Block/Customer/Group/Edit.php
+++ app/code/core/Mage/Adminhtml/Block/Customer/Group/Edit.php
@@ -57,7 +57,7 @@ class Mage_Adminhtml_Block_Customer_Group_Edit extends Mage_Adminhtml_Block_Widg
                 'form_key' => Mage::getSingleton('core/session')->getFormKey()
             ));
         } else {
-            parent::getDeleteUrl();
+            return parent::getDeleteUrl();
         }
     }
 
diff --git app/code/core/Mage/Adminhtml/Block/Permissions/Buttons.php app/code/core/Mage/Adminhtml/Block/Permissions/Buttons.php
index 4f7de832cff..8801e480caa 100644
--- app/code/core/Mage/Adminhtml/Block/Permissions/Buttons.php
+++ app/code/core/Mage/Adminhtml/Block/Permissions/Buttons.php
@@ -65,7 +65,7 @@ class Mage_Adminhtml_Block_Permissions_Buttons extends Mage_Adminhtml_Block_Temp
             $this->getLayout()->createBlock('adminhtml/widget_button')
                 ->setData(array(
                     'label'     => Mage::helper('adminhtml')->__('Delete Role'),
-                    'onclick'   => 'deleteConfirm(\'' . Mage::helper('adminhtml')->__('Are you sure you want to do this?') . '\', \'' . $this->getUrl('*/*/delete', array('rid' => $this->getRequest()->getParam('rid'))) . '\')',
+                    'onclick'   => 'deleteConfirm(\'' . Mage::helper('adminhtml')->__('Are you sure you want to do this?') . '\', \'' . $this->getUrlSecure('*/*/delete', array('rid' => $this->getRequest()->getParam('rid'))) . '\')',
                     'class' => 'delete'
                 ))
         );
diff --git app/code/core/Mage/Adminhtml/Block/System/Design/Edit.php app/code/core/Mage/Adminhtml/Block/System/Design/Edit.php
index 74bb72b5f3a..7fd8473a9cf 100644
--- app/code/core/Mage/Adminhtml/Block/System/Design/Edit.php
+++ app/code/core/Mage/Adminhtml/Block/System/Design/Edit.php
@@ -71,7 +71,10 @@ class Mage_Adminhtml_Block_System_Design_Edit extends Mage_Adminhtml_Block_Widge
 
     public function getDeleteUrl()
     {
-        return $this->getUrl('*/*/delete', array('_current'=>true));
+        return $this->getUrlSecure('*/*/delete', array(
+            'id' => $this->getDesignChangeId(),
+            Mage_Core_Model_Url::FORM_KEY => $this->getFormKey()
+        ));
     }
 
     public function getSaveUrl()
diff --git app/code/core/Mage/Adminhtml/Block/System/Store/Edit.php app/code/core/Mage/Adminhtml/Block/System/Store/Edit.php
index 6dddd33dd29..131373bf84f 100644
--- app/code/core/Mage/Adminhtml/Block/System/Store/Edit.php
+++ app/code/core/Mage/Adminhtml/Block/System/Store/Edit.php
@@ -40,24 +40,28 @@ class Mage_Adminhtml_Block_System_Store_Edit extends Mage_Adminhtml_Block_Widget
      */
     public function __construct()
     {
+        $backupAvailable =
+            Mage::getSingleton('admin/session')->isAllowed('system/tools/backup')
+            && Mage::helper('core')->isModuleEnabled('Mage_Backup')
+            && !Mage::getStoreConfigFlag('advanced/modules_disable_output/Mage_Backup');
         switch (Mage::registry('store_type')) {
             case 'website':
                 $this->_objectId = 'website_id';
                 $saveLabel   = Mage::helper('core')->__('Save Website');
                 $deleteLabel = Mage::helper('core')->__('Delete Website');
-                $deleteUrl   = $this->getUrl('*/*/deleteWebsite', array('item_id' => Mage::registry('store_data')->getId()));
+                $deleteUrl   = $this->_getDeleteUrl(Mage::registry('store_type'), $backupAvailable);
                 break;
             case 'group':
                 $this->_objectId = 'group_id';
                 $saveLabel   = Mage::helper('core')->__('Save Store');
                 $deleteLabel = Mage::helper('core')->__('Delete Store');
-                $deleteUrl   = $this->getUrl('*/*/deleteGroup', array('item_id' => Mage::registry('store_data')->getId()));
+                $deleteUrl   = $this->_getDeleteUrl(Mage::registry('store_type'), $backupAvailable);
                 break;
             case 'store':
                 $this->_objectId = 'store_id';
                 $saveLabel   = Mage::helper('core')->__('Save Store View');
                 $deleteLabel = Mage::helper('core')->__('Delete Store View');
-                $deleteUrl   = $this->getUrl('*/*/deleteStore', array('item_id' => Mage::registry('store_data')->getId()));
+                $deleteUrl   = $this->_getDeleteUrl(Mage::registry('store_type'), $backupAvailable);
                 break;
         }
         $this->_controller = 'system_store';
@@ -100,4 +104,29 @@ class Mage_Adminhtml_Block_System_Store_Edit extends Mage_Adminhtml_Block_Widget
 
         return Mage::registry('store_action') == 'add' ? $addLabel : $editLabel;
     }
+
+    /**
+     * Create URL depending on backups
+     *
+     * @param string $storeType
+     * @param bool $backupAvailable
+     * @return string
+     */
+    public function _getDeleteUrl($storeType, $backupAvailable = false)
+    {
+        $storeType = uc_words($storeType);
+        if ($backupAvailable) {
+            $deleteUrl   = $this->getUrl('*/*/delete' . $storeType, array('item_id' => Mage::registry('store_data')->getId()));
+        } else {
+            $deleteUrl   = $this->getUrl(
+                '*/*/delete' . $storeType . 'Post',
+                array(
+                    'item_id' => Mage::registry('store_data')->getId(),
+                    'form_key' => Mage::getSingleton('core/session')->getFormKey()
+                )
+            );
+        }
+
+        return $deleteUrl;
+    }
 }
diff --git app/code/core/Mage/Adminhtml/Controller/Action.php app/code/core/Mage/Adminhtml/Controller/Action.php
index e2478de12a0..ef17266c1d6 100644
--- app/code/core/Mage/Adminhtml/Controller/Action.php
+++ app/code/core/Mage/Adminhtml/Controller/Action.php
@@ -390,19 +390,59 @@ class Mage_Adminhtml_Controller_Action extends Mage_Core_Controller_Varien_Actio
      */
     protected function _checkIsForcedFormKeyAction()
     {
-        return in_array($this->getRequest()->getActionName(), $this->_forcedFormKeyActions);
+        return in_array(
+            strtolower($this->getRequest()->getActionName()),
+            array_map('strtolower', $this->_forcedFormKeyActions)
+        );
     }
 
     /**
-     * Set actions name for forced use form key
+     * Set actions name for forced use form key if "Secret Key to URLs" disabled
      *
      * @param array | string $actionNames - action names for forced use form key
      */
     protected function _setForcedFormKeyActions($actionNames)
     {
-        $actionNames = (is_array($actionNames)) ? $actionNames: (array)$actionNames;
-        $actionNames = array_merge($this->_forcedFormKeyActions, $actionNames);
-        $actionNames = array_unique($actionNames);
-        $this->_forcedFormKeyActions = $actionNames;
+        if (!Mage::helper('adminhtml')->isEnabledSecurityKeyUrl()) {
+            $actionNames = (is_array($actionNames)) ? $actionNames: (array)$actionNames;
+            $actionNames = array_merge($this->_forcedFormKeyActions, $actionNames);
+            $actionNames = array_unique($actionNames);
+            $this->_forcedFormKeyActions = $actionNames;
+        }
+    }
+
+    /**
+     * Validate request parameter
+     *
+     * @param string $param - request parameter
+     * @param string $pattern - pattern that should be contained in parameter
+     *
+     * @return bool
+     */
+    protected function _validateRequestParam($param, $pattern = '')
+    {
+        $pattern = empty($pattern) ? '/^[a-z0-9\-\_\/]*$/si' : $pattern;
+        if (preg_match($pattern, $param)) {
+            return true;
+        }
+        return false;
+    }
+
+    /**
+     * Validate request parameters
+     *
+     * @param array $params - array of request parameters
+     * @param string $pattern - pattern that should be contained in parameter
+     *
+     * @return bool
+     */
+    protected function _validateRequestParams($params, $pattern = '')
+    {
+        foreach ($params as $param) {
+            if (!$this->_validateRequestParam($param, $pattern)) {
+                return false;
+            }
+        }
+        return true;
     }
 }
diff --git app/code/core/Mage/Adminhtml/Helper/Data.php app/code/core/Mage/Adminhtml/Helper/Data.php
index c6d8a607b65..0281cf1721a 100644
--- app/code/core/Mage/Adminhtml/Helper/Data.php
+++ app/code/core/Mage/Adminhtml/Helper/Data.php
@@ -37,6 +37,7 @@ class Mage_Adminhtml_Helper_Data extends Mage_Core_Helper_Abstract
     const XML_PATH_USE_CUSTOM_ADMIN_URL         = 'default/admin/url/use_custom';
     const XML_PATH_USE_CUSTOM_ADMIN_PATH        = 'default/admin/url/use_custom_path';
     const XML_PATH_CUSTOM_ADMIN_PATH            = 'default/admin/url/custom_path';
+    const XML_PATH_ADMINHTML_SECURITY_USE_FORM_KEY = 'admin/security/use_form_key';
 
     protected $_pageHelpUrl;
 
@@ -122,4 +123,14 @@ class Mage_Adminhtml_Helper_Data extends Mage_Core_Helper_Abstract
     {
         $value = rawurldecode($value);
     }
+
+    /**
+     * Check if enabled "Add Secret Key to URLs" functionality
+     *
+     * @return bool
+     */
+    public function isEnabledSecurityKeyUrl()
+    {
+        return Mage::getStoreConfigFlag(self::XML_PATH_ADMINHTML_SECURITY_USE_FORM_KEY);
+    }
 }
diff --git app/code/core/Mage/Adminhtml/Model/Email/PathValidator.php app/code/core/Mage/Adminhtml/Model/Email/PathValidator.php
new file mode 100644
index 00000000000..70873f9c8f1
--- /dev/null
+++ app/code/core/Mage/Adminhtml/Model/Email/PathValidator.php
@@ -0,0 +1,45 @@
+<?php
+/**
+ * {license_notice}
+ *
+ * @copyright   {copyright}
+ * @license     {license_link}
+ */
+
+/**
+ * Validator for Email Template
+ *
+ * @category   Mage
+ * @package    Mage_Adminhtml
+ * @author     Magento Core Team <core@magentocommerce.com>
+ */
+class Mage_Adminhtml_Model_Email_PathValidator extends Zend_Validate_Abstract
+{
+    /**
+     * Returns true if and only if $value meets the validation requirements
+     * If $value fails validation, then this method returns false
+     *
+     * @param  mixed $value
+     * @return boolean
+     */
+    public function isValid($value)
+    {
+        $pathNode = is_array($value) ? array_shift($value) : $value;
+
+        return $this->isEncryptedNodePath($pathNode);
+    }
+
+    /**
+     * Return bool after checking the encrypted model in the path to config node
+     *
+     * @param string $path
+     * @return bool
+     */
+    protected function isEncryptedNodePath($path)
+    {
+        /** @var $configModel Mage_Adminhtml_Model_Config */
+        $configModel = Mage::getSingleton('adminhtml/config');
+
+        return in_array((string)$path, $configModel->getEncryptedNodeEntriesPaths());
+    }
+}
diff --git app/code/core/Mage/Adminhtml/Model/LayoutUpdate/Validator.php app/code/core/Mage/Adminhtml/Model/LayoutUpdate/Validator.php
index 21c86c2e979..0a0c78ef5a9 100644
--- app/code/core/Mage/Adminhtml/Model/LayoutUpdate/Validator.php
+++ app/code/core/Mage/Adminhtml/Model/LayoutUpdate/Validator.php
@@ -69,6 +69,7 @@ class Mage_Adminhtml_Model_LayoutUpdate_Validator extends Zend_Validate_Abstract
     protected $_disallowedBlock = array(
         'Mage_Install_Block_End',
         'Mage_Rss_Block_Order_New',
+        'Mage_Core_Block_Template_Zend',
     );
 
     /**
diff --git app/code/core/Mage/Adminhtml/Model/System/Config/Backend/Gatewayurl.php app/code/core/Mage/Adminhtml/Model/System/Config/Backend/Gatewayurl.php
new file mode 100644
index 00000000000..d6d9bb54563
--- /dev/null
+++ app/code/core/Mage/Adminhtml/Model/System/Config/Backend/Gatewayurl.php
@@ -0,0 +1,35 @@
+<?php
+/**
+ * {license_notice}
+ *
+ * @copyright   {copyright}
+ * @license     {license_link}
+ */
+
+/**
+ * Gateway URL config field backend model
+ *
+ * @category    Mage
+ * @package     Mage_Adminhtml
+ * @author      Magento Core Team <core@magentocommerce.com>
+ */
+class Mage_Adminhtml_Model_System_Config_Backend_Gatewayurl extends  Mage_Core_Model_Config_Data
+{
+    /**
+     * Before save processing
+     *
+     * @throws Mage_Core_Exception
+     * @return Mage_Adminhtml_Model_System_Config_Backend_Gatewayurl
+     */
+    protected function _beforeSave()
+    {
+        if ($this->getValue()) {
+            $parsed = parse_url($this->getValue());
+            if (!isset($parsed['scheme']) || (('https' != $parsed['scheme']) && ('http' != $parsed['scheme']))) {
+                Mage::throwException(Mage::helper('core')->__('Invalid URL scheme.'));
+            }
+        }
+
+        return $this;
+    }
+}
diff --git app/code/core/Mage/Adminhtml/Model/System/Config/Backend/Protected.php app/code/core/Mage/Adminhtml/Model/System/Config/Backend/Protected.php
new file mode 100644
index 00000000000..15659227f53
--- /dev/null
+++ app/code/core/Mage/Adminhtml/Model/System/Config/Backend/Protected.php
@@ -0,0 +1,17 @@
+<?php
+/**
+ * {license_notice}
+ *
+ * @copyright   {copyright}
+ * @license     {license_link}
+ */
+
+/**
+ * System config protected fields backend model
+ *
+ * @category Mage
+ * @package  Mage_Adminhtml
+ */
+class Mage_Adminhtml_Model_System_Config_Backend_Protected extends Mage_Adminhtml_Model_System_Config_Backend_Symlink
+{
+}
diff --git app/code/core/Mage/Adminhtml/controllers/Api/RoleController.php app/code/core/Mage/Adminhtml/controllers/Api/RoleController.php
index acbf6d79fb8..d1921b77094 100644
--- app/code/core/Mage/Adminhtml/controllers/Api/RoleController.php
+++ app/code/core/Mage/Adminhtml/controllers/Api/RoleController.php
@@ -33,6 +33,16 @@
  */
 class Mage_Adminhtml_Api_RoleController extends Mage_Adminhtml_Controller_Action
 {
+    /**
+     * Controller predispatch method
+     *
+     * @return Mage_Adminhtml_Controller_Action
+     */
+    public function preDispatch()
+    {
+        $this->_setForcedFormKeyActions(array('delete', 'save'));
+        return parent::preDispatch();
+    }
 
     protected function _initAction()
     {
diff --git app/code/core/Mage/Adminhtml/controllers/Api/UserController.php app/code/core/Mage/Adminhtml/controllers/Api/UserController.php
index ff3f81a6fca..6c84a1522fe 100644
--- app/code/core/Mage/Adminhtml/controllers/Api/UserController.php
+++ app/code/core/Mage/Adminhtml/controllers/Api/UserController.php
@@ -25,6 +25,16 @@
  */
 class Mage_Adminhtml_Api_UserController extends Mage_Adminhtml_Controller_Action
 {
+    /**
+     * Controller predispatch method
+     *
+     * @return Mage_Adminhtml_Controller_Action
+     */
+    public function preDispatch()
+    {
+        $this->_setForcedFormKeyActions('delete');
+        return parent::preDispatch();
+    }
 
     protected function _initAction()
     {
diff --git app/code/core/Mage/Adminhtml/controllers/Catalog/Product/Action/AttributeController.php app/code/core/Mage/Adminhtml/controllers/Catalog/Product/Action/AttributeController.php
index 888d436769e..a78729e9f52 100644
--- app/code/core/Mage/Adminhtml/controllers/Catalog/Product/Action/AttributeController.php
+++ app/code/core/Mage/Adminhtml/controllers/Catalog/Product/Action/AttributeController.php
@@ -62,6 +62,7 @@ class Mage_Adminhtml_Catalog_Product_Action_AttributeController extends Mage_Adm
         $attributesData     = $this->getRequest()->getParam('attributes', array());
         $websiteRemoveData  = $this->getRequest()->getParam('remove_website_ids', array());
         $websiteAddData     = $this->getRequest()->getParam('add_website_ids', array());
+        $attributeName      = '';
 
         /* Prepare inventory data item options (use config settings) */
         foreach (Mage::helper('cataloginventory')->getConfigItemOptions() as $option) {
@@ -74,6 +75,7 @@ class Mage_Adminhtml_Catalog_Product_Action_AttributeController extends Mage_Adm
             if ($attributesData) {
                 $dateFormat = Mage::app()->getLocale()->getDateFormat(Mage_Core_Model_Locale::FORMAT_TYPE_SHORT);
                 $storeId    = $this->_getHelper()->getSelectedStoreId();
+                $data       = new Varien_Object();
 
                 foreach ($attributesData as $attributeCode => $value) {
                     $attribute = Mage::getSingleton('eav/config')
@@ -82,6 +84,9 @@ class Mage_Adminhtml_Catalog_Product_Action_AttributeController extends Mage_Adm
                         unset($attributesData[$attributeCode]);
                         continue;
                     }
+                    $data->setData($attributeCode, $value);
+                    $attributeName = $attribute->getFrontendLabel();
+                    $attribute->getBackend()->validate($data);
                     if ($attribute->getBackendType() == 'datetime') {
                         if (!empty($value)) {
                             $filterInput    = new Zend_Filter_LocalizedToNormalized(array(
@@ -167,6 +172,9 @@ class Mage_Adminhtml_Catalog_Product_Action_AttributeController extends Mage_Adm
                 count($this->_getHelper()->getProductIds()))
             );
         }
+        catch (Mage_Eav_Model_Entity_Attribute_Exception $e) {
+            $this->_getSession()->addError($attributeName . ': ' . $e->getMessage());
+        }
         catch (Mage_Core_Exception $e) {
             $this->_getSession()->addError($e->getMessage());
         }
diff --git app/code/core/Mage/Adminhtml/controllers/Catalog/Product/AttributeController.php app/code/core/Mage/Adminhtml/controllers/Catalog/Product/AttributeController.php
index 8541195ce44..70fd8b07f31 100644
--- app/code/core/Mage/Adminhtml/controllers/Catalog/Product/AttributeController.php
+++ app/code/core/Mage/Adminhtml/controllers/Catalog/Product/AttributeController.php
@@ -39,6 +39,7 @@ class Mage_Adminhtml_Catalog_Product_AttributeController extends Mage_Adminhtml_
 
     public function preDispatch()
     {
+        $this->_setForcedFormKeyActions('delete');
         parent::preDispatch();
         $this->_entityTypeId = Mage::getModel('eav/entity')->setType(Mage_Catalog_Model_Product::ENTITY)->getTypeId();
     }
@@ -200,7 +201,7 @@ class Mage_Adminhtml_Catalog_Product_AttributeController extends Mage_Adminhtml_
 
             //validate attribute_code
             if (isset($data['attribute_code'])) {
-                $validatorAttrCode = new Zend_Validate_Regex(array('pattern' => '/^[a-z][a-z_0-9]{1,254}$/'));
+                $validatorAttrCode = new Zend_Validate_Regex(array('pattern' => '/^(?!event$)[a-z][a-z_0-9]{1,254}$/'));
                 if (!$validatorAttrCode->isValid($data['attribute_code'])) {
                     $session->addError(
                         $helper->__('Attribute code is invalid. Please use only letters (a-z), numbers (0-9) or underscore(_) in this field, first character should be a letter.'));
diff --git app/code/core/Mage/Adminhtml/controllers/Catalog/Product/WidgetController.php app/code/core/Mage/Adminhtml/controllers/Catalog/Product/WidgetController.php
index 0ca8d49e79e..b5dacfe99c8 100644
--- app/code/core/Mage/Adminhtml/controllers/Catalog/Product/WidgetController.php
+++ app/code/core/Mage/Adminhtml/controllers/Catalog/Product/WidgetController.php
@@ -36,6 +36,9 @@ class Mage_Adminhtml_Catalog_Product_WidgetController extends Mage_Adminhtml_Con
 {
     /**
      * Chooser Source action
+     *
+     * @throws Mage_Core_Exception
+     * @return void
      */
     public function chooserAction()
     {
@@ -43,6 +46,10 @@ class Mage_Adminhtml_Catalog_Product_WidgetController extends Mage_Adminhtml_Con
         $massAction = $this->getRequest()->getParam('use_massaction', false);
         $productTypeId = $this->getRequest()->getParam('product_type_id', null);
 
+        if (!$this->_validateRequestParam($uniqId)) {
+            Mage::throwException(Mage::helper('adminhtml')->__('An error occurred while adding condition.'));
+        }
+
         $productsGrid = $this->getLayout()->createBlock('adminhtml/catalog_product_widget_chooser', '', array(
             'id'                => $uniqId,
             'use_massaction' => $massAction,
diff --git app/code/core/Mage/Adminhtml/controllers/Catalog/ProductController.php app/code/core/Mage/Adminhtml/controllers/Catalog/ProductController.php
index 0faf4eea317..96af92ebde8 100644
--- app/code/core/Mage/Adminhtml/controllers/Catalog/ProductController.php
+++ app/code/core/Mage/Adminhtml/controllers/Catalog/ProductController.php
@@ -45,6 +45,17 @@ class Mage_Adminhtml_Catalog_ProductController extends Mage_Adminhtml_Controller
      */
     protected $_publicActions = array('edit');
 
+    /**
+     * Controller predispatch method
+     *
+     * @return Mage_Adminhtml_Controller_Action
+     */
+    public function preDispatch()
+    {
+        $this->_setForcedFormKeyActions(array('delete', 'massDelete'));
+        return parent::preDispatch();
+    }
+
     protected function _construct()
     {
         // Define module dependent translate
diff --git app/code/core/Mage/Adminhtml/controllers/Cms/WysiwygController.php app/code/core/Mage/Adminhtml/controllers/Cms/WysiwygController.php
index 0db5b3bbfee..6632e168bc4 100644
--- app/code/core/Mage/Adminhtml/controllers/Cms/WysiwygController.php
+++ app/code/core/Mage/Adminhtml/controllers/Cms/WysiwygController.php
@@ -44,6 +44,10 @@ class Mage_Adminhtml_Cms_WysiwygController extends Mage_Adminhtml_Controller_Act
         $directive = Mage::helper('core')->urlDecode($directive);
         $url = Mage::getModel('core/email_template_filter')->filter($directive);
         try {
+            $allowedStreamWrappers = Mage::helper('cms')->getAllowedStreamWrappers();
+            if (!Mage::getModel('core/file_validator_streamWrapper', $allowedStreamWrappers)->validate($url)) {
+                Mage::throwException(Mage::helper('core')->__('Invalid stream.'));
+            }
             $image = Varien_Image_Adapter::factory('GD2');
             $image->open($url);
         } catch (Exception $e) {
diff --git app/code/core/Mage/Adminhtml/controllers/CustomerController.php app/code/core/Mage/Adminhtml/controllers/CustomerController.php
index 570df040f1c..75fdb252d0e 100644
--- app/code/core/Mage/Adminhtml/controllers/CustomerController.php
+++ app/code/core/Mage/Adminhtml/controllers/CustomerController.php
@@ -40,7 +40,7 @@ class Mage_Adminhtml_CustomerController extends Mage_Adminhtml_Controller_Action
      */
     public function preDispatch()
     {
-        $this->_setForcedFormKeyActions('delete');
+        $this->_setForcedFormKeyActions(array('delete', 'massDelete'));
         return parent::preDispatch();
     }
 
diff --git app/code/core/Mage/Adminhtml/controllers/Permissions/RoleController.php app/code/core/Mage/Adminhtml/controllers/Permissions/RoleController.php
index 8ecabf29f59..f167ac7a6d3 100644
--- app/code/core/Mage/Adminhtml/controllers/Permissions/RoleController.php
+++ app/code/core/Mage/Adminhtml/controllers/Permissions/RoleController.php
@@ -34,6 +34,17 @@
 class Mage_Adminhtml_Permissions_RoleController extends Mage_Adminhtml_Controller_Action
 {
 
+    /**
+     * Controller predispatch method
+     *
+     * @return Mage_Adminhtml_Controller_Action
+     */
+    public function preDispatch()
+    {
+        $this->_setForcedFormKeyActions('delete');
+        return parent::preDispatch();
+    }
+
     /**
      * Preparing layout for output
      *
@@ -138,6 +149,13 @@ class Mage_Adminhtml_Permissions_RoleController extends Mage_Adminhtml_Controlle
     {
         $rid = $this->getRequest()->getParam('rid', false);
 
+        $role = $this->_initRole();
+        if (!$role->getId()) {
+            Mage::getSingleton('adminhtml/session')->addError($this->__('This Role no longer exists.'));
+            $this->_redirect('*/*/');
+            return;
+        }
+
         $currentUser = Mage::getModel('admin/user')->setId(Mage::getSingleton('admin/session')->getUser()->getId());
 
         if (in_array($rid, $currentUser->getRoles()) ) {
@@ -147,7 +165,7 @@ class Mage_Adminhtml_Permissions_RoleController extends Mage_Adminhtml_Controlle
         }
 
         try {
-            $role = $this->_initRole()->delete();
+            $role->delete();
 
             Mage::getSingleton('adminhtml/session')->addSuccess($this->__('The role has been deleted.'));
         } catch (Exception $e) {
diff --git app/code/core/Mage/Adminhtml/controllers/Permissions/UserController.php app/code/core/Mage/Adminhtml/controllers/Permissions/UserController.php
index e3780ff8621..7850c209e41 100644
--- app/code/core/Mage/Adminhtml/controllers/Permissions/UserController.php
+++ app/code/core/Mage/Adminhtml/controllers/Permissions/UserController.php
@@ -25,6 +25,16 @@
  */
 class Mage_Adminhtml_Permissions_UserController extends Mage_Adminhtml_Controller_Action
 {
+    /**
+     * Controller predispatch method
+     *
+     * @return Mage_Adminhtml_Controller_Action
+     */
+    public function preDispatch()
+    {
+        $this->_setForcedFormKeyActions('delete');
+        return parent::preDispatch();
+    }
 
     protected function _initAction()
     {
diff --git app/code/core/Mage/Adminhtml/controllers/Promo/CatalogController.php app/code/core/Mage/Adminhtml/controllers/Promo/CatalogController.php
index 1309281c607..f4d57048d24 100644
--- app/code/core/Mage/Adminhtml/controllers/Promo/CatalogController.php
+++ app/code/core/Mage/Adminhtml/controllers/Promo/CatalogController.php
@@ -33,6 +33,17 @@
  */
 class Mage_Adminhtml_Promo_CatalogController extends Mage_Adminhtml_Controller_Action
 {
+    /**
+     * Controller predispatch method
+     *
+     * @return Mage_Adminhtml_Controller_Action
+     */
+    public function preDispatch()
+    {
+        $this->_setForcedFormKeyActions('delete');
+        return parent::preDispatch();
+    }
+
     protected function _initAction()
     {
         $this->loadLayout()
@@ -187,6 +198,13 @@ class Mage_Adminhtml_Promo_CatalogController extends Mage_Adminhtml_Controller_A
             try {
                 $model = Mage::getModel('catalogrule/rule');
                 $model->load($id);
+                if (!$model->getRuleId()) {
+                    Mage::getSingleton('adminhtml/session')->addError(
+                        Mage::helper('catalogrule')->__('Unable to find a rule to delete.')
+                    );
+                    $this->_redirect('*/*/');
+                    return;
+                }
                 $model->delete();
                 Mage::app()->saveCache(1, 'catalog_rules_dirty');
                 Mage::getSingleton('adminhtml/session')->addSuccess(
diff --git app/code/core/Mage/Adminhtml/controllers/Promo/QuoteController.php app/code/core/Mage/Adminhtml/controllers/Promo/QuoteController.php
index c69ca8bc300..fb166ecd769 100644
--- app/code/core/Mage/Adminhtml/controllers/Promo/QuoteController.php
+++ app/code/core/Mage/Adminhtml/controllers/Promo/QuoteController.php
@@ -27,6 +27,18 @@
 
 class Mage_Adminhtml_Promo_QuoteController extends Mage_Adminhtml_Controller_Action
 {
+    /**
+    * Controller predispatch method
+    *
+    * @return Mage_Adminhtml_Controller_Action
+    */
+
+    public function preDispatch()
+    {
+        $this->_setForcedFormKeyActions('delete');
+        return parent::preDispatch();
+    }
+
     protected function _initRule()
     {
         $this->_title($this->__('Promotions'))->_title($this->__('Shopping Cart Price Rules'));
@@ -190,6 +202,15 @@ class Mage_Adminhtml_Promo_QuoteController extends Mage_Adminhtml_Controller_Act
             try {
                 $model = Mage::getModel('salesrule/rule');
                 $model->load($id);
+
+                if (!$model->getRuleId()) {
+                    Mage::getSingleton('adminhtml/session')->addError(
+                        Mage::helper('catalogrule')->__('Unable to find a rule to delete.')
+                    );
+                    $this->_redirect('*/*/');
+                    return;
+                }
+
                 $model->delete();
                 Mage::getSingleton('adminhtml/session')->addSuccess(
                     Mage::helper('salesrule')->__('The rule has been deleted.'));
@@ -210,12 +231,25 @@ class Mage_Adminhtml_Promo_QuoteController extends Mage_Adminhtml_Controller_Act
         $this->_redirect('*/*/');
     }
 
+    /**
+     * New condition HTML action
+     *
+     * @throws Mage_Core_Exception
+     * @return void
+     */
     public function newConditionHtmlAction()
     {
         $id = $this->getRequest()->getParam('id');
         $typeArr = explode('|', str_replace('-', '/', $this->getRequest()->getParam('type')));
         $type = $typeArr[0];
 
+        if (!$this->_validateRequestParams(array($id, $type))) {
+            if ($this->getRequest()->getQuery('id')) {
+                $this->getRequest()->setQuery('id', '');
+            }
+            Mage::throwException(Mage::helper('adminhtml')->__('An error occurred while adding condition.'));
+        }
+
         $model = Mage::getModel($type)
             ->setId($id)
             ->setType($type)
diff --git app/code/core/Mage/Adminhtml/controllers/System/BackupController.php app/code/core/Mage/Adminhtml/controllers/System/BackupController.php
index 7eda85d761d..1ab82a90c3f 100644
--- app/code/core/Mage/Adminhtml/controllers/System/BackupController.php
+++ app/code/core/Mage/Adminhtml/controllers/System/BackupController.php
@@ -40,7 +40,7 @@ class Mage_Adminhtml_System_BackupController extends Mage_Adminhtml_Controller_A
      */
     public function preDispatch()
     {
-        $this->_setForcedFormKeyActions('create');
+        $this->_setForcedFormKeyActions(array('create', 'massDelete'));
         return parent::preDispatch();
     }
 
diff --git app/code/core/Mage/Adminhtml/controllers/System/DesignController.php app/code/core/Mage/Adminhtml/controllers/System/DesignController.php
index 973adf65f86..c2b9a976f4f 100644
--- app/code/core/Mage/Adminhtml/controllers/System/DesignController.php
+++ app/code/core/Mage/Adminhtml/controllers/System/DesignController.php
@@ -27,6 +27,17 @@
 
 class Mage_Adminhtml_System_DesignController extends Mage_Adminhtml_Controller_Action
 {
+    /**
+     * Controller predispatch method
+     *
+     * @return Mage_Adminhtml_Controller_Action
+     */
+    public function preDispatch()
+    {
+        $this->_setForcedFormKeyActions('delete');
+        return parent::preDispatch();
+    }
+
     public function indexAction()
     {
         $this->_title($this->__('System'))->_title($this->__('Design'));
diff --git app/code/core/Mage/Catalog/Model/Product/Option/Type/Select.php app/code/core/Mage/Catalog/Model/Product/Option/Type/Select.php
index 80de23dfc89..093f0aa6fc8 100644
--- app/code/core/Mage/Catalog/Model/Product/Option/Type/Select.php
+++ app/code/core/Mage/Catalog/Model/Product/Option/Type/Select.php
@@ -54,7 +54,8 @@ class Mage_Catalog_Model_Product_Option_Type_Select extends Mage_Catalog_Model_P
         if (!$this->_isSingleSelection()) {
             $valuesCollection = $option->getOptionValuesByOptionId($value, $this->getProduct()->getStoreId())
                 ->load();
-            if ($valuesCollection->count() != count($value)) {
+            $valueCount = empty($value) ? 0 : count($value);
+            if ($valuesCollection->count() != $valueCount) {
                 $this->setIsValid(false);
                 Mage::throwException(Mage::helper('catalog')->__('Please specify the product required option(s).'));
             }
diff --git app/code/core/Mage/Cms/Helper/Data.php app/code/core/Mage/Cms/Helper/Data.php
index a0735d63c7d..ca06a14cd74 100644
--- app/code/core/Mage/Cms/Helper/Data.php
+++ app/code/core/Mage/Cms/Helper/Data.php
@@ -36,6 +36,7 @@ class Mage_Cms_Helper_Data extends Mage_Core_Helper_Abstract
 {
     const XML_NODE_PAGE_TEMPLATE_FILTER     = 'global/cms/page/tempate_filter';
     const XML_NODE_BLOCK_TEMPLATE_FILTER    = 'global/cms/block/tempate_filter';
+    const XML_NODE_ALLOWED_STREAM_WRAPPERS  = 'global/cms/allowed_stream_wrappers';
 
     /**
      * Retrieve Template processor for Page Content
@@ -58,4 +59,19 @@ class Mage_Cms_Helper_Data extends Mage_Core_Helper_Abstract
         $model = (string)Mage::getConfig()->getNode(self::XML_NODE_BLOCK_TEMPLATE_FILTER);
         return Mage::getModel($model);
     }
+
+    /**
+     * Return list with allowed stream wrappers
+     *
+     * @return array
+     */
+    public function getAllowedStreamWrappers()
+    {
+        $allowedStreamWrappers = Mage::getConfig()->getNode(self::XML_NODE_ALLOWED_STREAM_WRAPPERS);
+        if ($allowedStreamWrappers instanceof Mage_Core_Model_Config_Element) {
+            $allowedStreamWrappers = $allowedStreamWrappers->asArray();
+        }
+
+        return is_array($allowedStreamWrappers) ? $allowedStreamWrappers : array();
+    }
 }
diff --git app/code/core/Mage/Cms/etc/config.xml app/code/core/Mage/Cms/etc/config.xml
index eaebe049186..3539478c7c7 100644
--- app/code/core/Mage/Cms/etc/config.xml
+++ app/code/core/Mage/Cms/etc/config.xml
@@ -190,6 +190,10 @@
             <block>
                 <tempate_filter>cms/template_filter</tempate_filter>
             </block>
+            <allowed_stream_wrappers>
+                <http>http</http>
+                <https>https</https>
+            </allowed_stream_wrappers>
         </cms>
     </global>
     <default>
diff --git app/code/core/Mage/Core/Block/Abstract.php app/code/core/Mage/Core/Block/Abstract.php
index ed7aadf80c6..9cdb2bcf2ea 100644
--- app/code/core/Mage/Core/Block/Abstract.php
+++ app/code/core/Mage/Core/Block/Abstract.php
@@ -947,6 +947,22 @@ abstract class Mage_Core_Block_Abstract extends Varien_Object
         return $this->_getUrlModel()->getUrl($route, $params);
     }
 
+    /**
+     * Generate security url by route and parameters (add form key if "Add Secret Key to URLs" disabled)
+     *
+     * @param string $route
+     * @param array $params
+     *
+     * @return string
+     */
+    public function getUrlSecure($route = '', $params = array())
+    {
+        if (!Mage::helper('adminhtml')->isEnabledSecurityKeyUrl()) {
+            $params[Mage_Core_Model_Url::FORM_KEY] = $this->getFormKey();
+        }
+        return $this->getUrl($route, $params);
+    }
+
     /**
      * Generate base64-encoded url by route and parameters
      *
diff --git app/code/core/Mage/Core/Helper/Abstract.php app/code/core/Mage/Core/Helper/Abstract.php
index 988dab7a8de..f69972b2279 100644
--- app/code/core/Mage/Core/Helper/Abstract.php
+++ app/code/core/Mage/Core/Helper/Abstract.php
@@ -271,7 +271,45 @@ abstract class Mage_Core_Helper_Abstract
      */
     public function escapeUrl($data)
     {
-        return htmlspecialchars($data);
+        return htmlspecialchars(
+            $this->escapeScriptIdentifiers((string) $data),
+            ENT_COMPAT | ENT_HTML5 | ENT_HTML401,
+            'UTF-8'
+        );
+    }
+
+    /**
+     * Remove `\t`,`\n`,`\r`,`\0`,`\x0B:` symbols from the string.
+     *
+     * @param string $data
+     * @return string
+     */
+    public function escapeSpecial($data)
+    {
+        $specialSymbolsFiltrationPattern = '/[\t\n\r\0\x0B]+/';
+
+        return (string) preg_replace($specialSymbolsFiltrationPattern, '', $data);
+    }
+
+    /**
+     * Remove `javascript:`, `vbscript:`, `data:` words from the string.
+     *
+     * @param string $data
+     * @return string
+     */
+    public function escapeScriptIdentifiers($data)
+    {
+        $scripIdentifiersFiltrationPattern = '/((javascript(\\\\x3a|:|%3A))|(data(\\\\x3a|:|%3A))|(vbscript:))|'
+            . '((\\\\x6A\\\\x61\\\\x76\\\\x61\\\\x73\\\\x63\\\\x72\\\\x69\\\\x70\\\\x74(\\\\x3a|:|%3A))|'
+            . '(\\\\x64\\\\x61\\\\x74\\\\x61(\\\\x3a|:|%3A)))/i';
+
+        $preFilteredData = $this->escapeSpecial($data);
+        $filteredData = preg_replace($scripIdentifiersFiltrationPattern, ':', $preFilteredData) ?: '';
+        if (preg_match($scripIdentifiersFiltrationPattern, $filteredData)) {
+            $filteredData = $this->escapeScriptIdentifiers($filteredData);
+        }
+
+        return $filteredData;
     }
 
     /**
diff --git app/code/core/Mage/Core/Model/File/Validator/StreamWrapper.php app/code/core/Mage/Core/Model/File/Validator/StreamWrapper.php
new file mode 100644
index 00000000000..5f3752d268a
--- /dev/null
+++ app/code/core/Mage/Core/Model/File/Validator/StreamWrapper.php
@@ -0,0 +1,51 @@
+<?php
+/**
+ * {license_notice}
+ *
+ * @copyright   {copyright}
+ * @license     {license_link}
+ */
+
+/**
+ * Validator for check is stream wrapper allowed
+ *
+ * @category   Mage
+ * @package    Mage_Core
+ * @author     Magento Core Team <core@magentocommerce.com>
+ */
+class Mage_Core_Model_File_Validator_StreamWrapper
+{
+    /**
+     * Allowed stream wrappers
+     *
+     * @var array
+     */
+    protected $_allowedStreamWrappers = array();
+
+    /**
+     * Mage_Core_Model_File_Validator_StreamWrapper constructor.
+     *
+     * @param array $allowedStreamWrappers
+     */
+    public function __construct($allowedStreamWrappers = array())
+    {
+        $this->_allowedStreamWrappers = $allowedStreamWrappers;
+    }
+
+    /**
+     * Validation callback for checking is stream wrapper allowed
+     *
+     * @param  string $filePath Path to file
+     * @return boolean
+     */
+    public function validate($filePath)
+    {
+        if (($pos = strpos($filePath, '://')) > 0) {
+            $wrapper = substr($filePath, 0, $pos);
+            if (!in_array($wrapper, $this->_allowedStreamWrappers)) {
+                 return false;
+            }
+        }
+        return true;
+    }
+}
diff --git app/code/core/Mage/Core/Model/Input/Filter/MaliciousCode.php app/code/core/Mage/Core/Model/Input/Filter/MaliciousCode.php
index dcfae819a4c..6946befbea2 100644
--- app/code/core/Mage/Core/Model/Input/Filter/MaliciousCode.php
+++ app/code/core/Mage/Core/Model/Input/Filter/MaliciousCode.php
@@ -50,7 +50,7 @@ class Mage_Core_Model_Input_Filter_MaliciousCode implements Zend_Filter_Interfac
         //js in the style attribute
         '/style=[^<]*((expression\s*?\([^<]*?\))|(behavior\s*:))[^<]*(?=\>)/Uis',
         //js attributes
-        '/(ondblclick|onclick|onkeydown|onkeypress|onkeyup|onmousedown|onmousemove|onmouseout|onmouseover|onmouseup|onload|onunload|onerror)\s*=[^<]*(?=\>)/Uis',
+        '/(ondblclick|onclick|onkeydown|onkeypress|onkeyup|onmousedown|onmousemove|onmouseout|onmouseover|onmouseup|onload|onunload|onerror)\s*=[^>]*(?=\>)/Uis',
         //tags
         '/<\/?(script|meta|link|frame|iframe).*>/Uis',
         //base64 usage
diff --git app/code/core/Mage/Core/etc/system.xml app/code/core/Mage/Core/etc/system.xml
index 9246456d320..789ff76d62d 100644
--- app/code/core/Mage/Core/etc/system.xml
+++ app/code/core/Mage/Core/etc/system.xml
@@ -738,6 +738,21 @@
                         </weekend>
                     </fields>
                 </locale>
+                <file>
+                    <label>File Settings</label>
+                    <frontend_type>text</frontend_type>
+                    <show_in_default>0</show_in_default>
+                    <show_in_website>0</show_in_website>
+                    <show_in_store>0</show_in_store>
+                    <fields>
+                        <protected_extensions>
+                            <backend_model>adminhtml/system_config_backend_protected</backend_model>
+                            <show_in_default>0</show_in_default>
+                            <show_in_website>0</show_in_website>
+                            <show_in_store>0</show_in_store>
+                        </protected_extensions>
+                    </fields>
+                </file>
                 <store_information translate="label">
                     <label>Store Information</label>
                     <frontend_type>text</frontend_type>
diff --git app/code/core/Mage/Eav/Model/Attribute/Data/File.php app/code/core/Mage/Eav/Model/Attribute/Data/File.php
index 295c4353446..720ad53b078 100644
--- app/code/core/Mage/Eav/Model/Attribute/Data/File.php
+++ app/code/core/Mage/Eav/Model/Attribute/Data/File.php
@@ -184,6 +184,7 @@ class Mage_Eav_Model_Attribute_Data_File extends Mage_Eav_Model_Attribute_Data_A
         }
 
         if (count($errors) == 0) {
+            $attribute->setAttributeValidationAsPassed();
             return true;
         }
 
@@ -204,6 +205,10 @@ class Mage_Eav_Model_Attribute_Data_File extends Mage_Eav_Model_Attribute_Data_A
         }
 
         $attribute = $this->getAttribute();
+        if (!$attribute->isAttributeValidationPassed()) {
+            return $this;
+        }
+
         $original  = $this->getEntity()->getData($attribute->getAttributeCode());
         $toDelete  = false;
         if ($original) {
diff --git app/code/core/Mage/Eav/Model/Entity/Attribute/Abstract.php app/code/core/Mage/Eav/Model/Entity/Attribute/Abstract.php
index 6dfb1fddf76..84e068854e7 100644
--- app/code/core/Mage/Eav/Model/Entity/Attribute/Abstract.php
+++ app/code/core/Mage/Eav/Model/Entity/Attribute/Abstract.php
@@ -86,6 +86,13 @@ abstract class Mage_Eav_Model_Entity_Attribute_Abstract extends Mage_Core_Model_
      */
     protected $_dataTable                   = null;
 
+    /**
+     * Attribute validation flag
+     *
+     * @var boolean
+     */
+    protected $_attributeValidationPassed   = false;
+
     /**
      * Initialize resource model
      */
@@ -121,6 +128,16 @@ abstract class Mage_Eav_Model_Entity_Attribute_Abstract extends Mage_Core_Model_
         return $this;
     }
 
+    /**
+     * Mark current attribute as passed validation
+     *
+     * @return void
+     */
+    public function setAttributeValidationAsPassed()
+    {
+        $this->_attributeValidationPassed = true;
+    }
+
     /**
      * Retrieve attribute configuration (deprecated)
      *
@@ -423,6 +440,16 @@ abstract class Mage_Eav_Model_Entity_Attribute_Abstract extends Mage_Core_Model_
         return $isEmpty;
     }
 
+    /**
+     * Check if attribute is valid
+     *
+     * @return boolean
+     */
+    public function isAttributeValidationPassed()
+    {
+        return $this->_attributeValidationPassed;
+    }
+
     /**
      * Check if attribute in specified set
      *
diff --git app/code/core/Mage/Rss/etc/system.xml app/code/core/Mage/Rss/etc/system.xml
index c776571189d..5493ccf0392 100644
--- app/code/core/Mage/Rss/etc/system.xml
+++ app/code/core/Mage/Rss/etc/system.xml
@@ -141,8 +141,9 @@
                     <show_in_website>1</show_in_website>
                     <show_in_store>1</show_in_store>
                     <fields>
-                         <status_notified translate="label">
+                         <status_notified translate="label comment">
                             <label>Customer Order Status Notification</label>
+                            <comment>Enabling can increase security risk by exposing some order details.</comment>
                             <frontend_type>select</frontend_type>
                             <source_model>adminhtml/system_config_source_enabledisable</source_model>
                             <sort_order>10</sort_order>
diff --git app/code/core/Mage/Usa/etc/system.xml app/code/core/Mage/Usa/etc/system.xml
index 31b9ed1f22f..9b9984ea9ae 100644
--- app/code/core/Mage/Usa/etc/system.xml
+++ app/code/core/Mage/Usa/etc/system.xml
@@ -124,6 +124,7 @@
                         <gateway_url translate="label">
                             <label>Gateway URL</label>
                             <frontend_type>text</frontend_type>
+                            <backend_model>adminhtml/system_config_backend_gatewayurl</backend_model>
                             <sort_order>20</sort_order>
                             <show_in_default>1</show_in_default>
                             <show_in_website>1</show_in_website>
@@ -696,6 +697,7 @@
                         <gateway_url translate="label">
                             <label>Gateway URL</label>
                             <frontend_type>text</frontend_type>
+                            <backend_model>adminhtml/system_config_backend_gatewayurl</backend_model>
                             <sort_order>40</sort_order>
                             <show_in_default>1</show_in_default>
                             <show_in_website>1</show_in_website>
@@ -713,6 +715,7 @@
                         <gateway_xml_url translate="label">
                             <label>Gateway XML URL</label>
                             <frontend_type>text</frontend_type>
+                            <backend_model>adminhtml/system_config_backend_gatewayurl</backend_model>
                             <sort_order>30</sort_order>
                             <show_in_default>1</show_in_default>
                             <show_in_website>1</show_in_website>
@@ -795,7 +798,7 @@
                             <show_in_default>1</show_in_default>
                             <show_in_website>1</show_in_website>
                             <show_in_store>0</show_in_store>
-                        0</sort_order>
+                        </sort_order>
                         <title translate="label">
                             <label>Title</label>
                             <frontend_type>text</frontend_type>
diff --git app/code/core/Mage/Widget/controllers/Adminhtml/Widget/InstanceController.php app/code/core/Mage/Widget/controllers/Adminhtml/Widget/InstanceController.php
index 821af49dbfc..87f55d8468f 100644
--- app/code/core/Mage/Widget/controllers/Adminhtml/Widget/InstanceController.php
+++ app/code/core/Mage/Widget/controllers/Adminhtml/Widget/InstanceController.php
@@ -156,7 +156,7 @@ class Mage_Widget_Adminhtml_Widget_InstanceController extends Mage_Adminhtml_Con
     public function saveAction()
     {
         $widgetInstance = $this->_initWidgetInstance();
-        if (!$widgetInstance) {
+        if (!$widgetInstance || !$this->_validatePostData($widgetInstance, $this->getRequest()->getPost())) {
             $this->_redirect('*/*/');
             return;
         }
@@ -309,4 +309,44 @@ class Mage_Widget_Adminhtml_Widget_InstanceController extends Mage_Adminhtml_Con
         }
         return $result;
     }
+
+    /**
+     * Validates update xml post data
+     *
+     * @param $widgetInstance
+     * @param $data
+     * @return bool
+     */
+    protected function _validatePostData($widgetInstance, $data)
+    {
+        $errorNo = true;
+        if (!empty($data['widget_instance']) && is_array($data['widget_instance'])) {
+            /** @var $validatorCustomLayout Mage_Adminhtml_Model_LayoutUpdate_Validator */
+            $validatorCustomLayout = Mage::getModel('adminhtml/layoutUpdate_validator');
+            foreach ($data['widget_instance'] as $pageGroup) {
+                try {
+                    if (
+                        !empty($pageGroup['page_group'])
+                        && !empty($pageGroup[$pageGroup['page_group']]['template'])
+                        && !empty($pageGroup[$pageGroup['page_group']]['block'])
+                        && !$validatorCustomLayout->isValid($widgetInstance->generateLayoutUpdateXml(
+                            $pageGroup[$pageGroup['page_group']]['block'],
+                            $pageGroup[$pageGroup['page_group']]['template']))
+                    ) {
+                        $errorNo = false;
+                    }
+                } catch (Exception $exception) {
+                    Mage::logException($exception);
+                    $this->_getSession()->addError(
+                        $this->__('An error occurred during POST data validation: %s', $exception->getMessage())
+                    );
+                    $errorNo = false;
+                }
+            }
+            foreach ($validatorCustomLayout->getMessages() as $message) {
+                $this->_getSession()->addError($message);
+            }
+        }
+        return $errorNo;
+    }
 }
diff --git app/design/frontend/enterprise/default/template/giftcardaccount/onepage/payment/additional.phtml app/design/frontend/enterprise/default/template/giftcardaccount/onepage/payment/additional.phtml
index 591e1e13088..eb860160d11 100644
--- app/design/frontend/enterprise/default/template/giftcardaccount/onepage/payment/additional.phtml
+++ app/design/frontend/enterprise/default/template/giftcardaccount/onepage/payment/additional.phtml
@@ -27,7 +27,8 @@
 <div class="checkout-onepage-payment-additional-giftcardaccount">
 <p class="note">
     <?php $_url = Mage::getUrl('checkout/cart'); ?>
-    <?php echo Mage::helper('enterprise_giftcardaccount')->__('To add or remove gift cards, <a href="%s">click here</a>.', $_url); ?><br />
+    <?php echo Mage::helper('enterprise_giftcardaccount')->__('To add or remove gift cards,') ?>
+    <a href="<?php echo $_url ?>"><?php echo Mage::helper('enterprise_giftcardaccount')->__('click here') ?>.</a><br />
 
     <?php if ((float)$this->getAppliedGiftCardAmount()): ?>
         <?php $amount = Mage::helper('core')->currency($this->getAppliedGiftCardAmount(), true); ?>
diff --git app/etc/config.xml app/etc/config.xml
index 75bb34b105d..e8bcfe1e3b7 100644
--- app/etc/config.xml
+++ app/etc/config.xml
@@ -144,6 +144,10 @@
             <template>
                 <allow_symlink>0</allow_symlink>
             </template>
+            <log>
+                <file>system.log</file>
+                <allowedFileExtensions>log,txt,html,csv</allowedFileExtensions>
+            </log>
         </dev>
         <general>
             <locale>
diff --git app/locale/en_US/Enterprise_GiftCardAccount.csv app/locale/en_US/Enterprise_GiftCardAccount.csv
index 099644b145b..e822b014753 100644
--- app/locale/en_US/Enterprise_GiftCardAccount.csv
+++ app/locale/en_US/Enterprise_GiftCardAccount.csv
@@ -119,6 +119,7 @@
 "This Gift Card Account no longer exists.","This Gift Card Account no longer exists."
 "This gift card account is already in the quote.","This gift card account is already in the quote."
 "This gift card account wasn\'t found in the quote.","This gift card account wasn\'t found in the quote."
+"To add or remove gift cards,","To add or remove gift cards,"
 "To add or remove gift cards, <a href=""%s"">click here</a>.","To add or remove gift cards, <a href=""%s"">click here</a>."
 "Total of %d record(s) have been deleted.","Total of %d record(s) have been deleted."
 "Unable to create full code pool size. Please check settings and try again.","Unable to create full code pool size. Please check settings and try again."
@@ -136,4 +137,5 @@
 "Wrong gift card code.","Wrong gift card code."
 "Wrong or expired Gift Card Code.","Wrong or expired Gift Card Code."
 "Yes","Yes"
+"click here","click here"
 "if empty no separation.","if empty no separation."
diff --git app/locale/en_US/Mage_Adminhtml.csv app/locale/en_US/Mage_Adminhtml.csv
index 80297b53a2b..7c8e7b657f9 100644
--- app/locale/en_US/Mage_Adminhtml.csv
+++ app/locale/en_US/Mage_Adminhtml.csv
@@ -100,6 +100,7 @@
 "All valid rates have been saved.","All valid rates have been saved."
 "Amounts","Amounts"
 "An error has occured while syncronizing media storages.","An error has occured while syncronizing media storages."
+"An error occurred while adding condition.","An error occurred while adding condition."
 "An error occurred while clearing the JavaScript/CSS cache.","An error occurred while clearing the JavaScript/CSS cache."
 "An error occurred while clearing the image cache.","An error occurred while clearing the image cache."
 "An error occurred while creating the backup.","An error occurred while creating the backup."
@@ -110,6 +111,7 @@
 "An error occurred while deleting this set.","An error occurred while deleting this set."
 "An error occurred while deleting this template.","An error occurred while deleting this template."
 "An error occurred while finishing process. Please refresh the cache","An error occurred while finishing process. Please refresh the cache"
+"An error occurred while logging in.","An error occurred while logging in."
 "An error occurred while rebuilding the CatalogInventory Stock Status.","An error occurred while rebuilding the CatalogInventory Stock Status."
 "An error occurred while rebuilding the catalog index.","An error occurred while rebuilding the catalog index."
 "An error occurred while rebuilding the flat catalog category.","An error occurred while rebuilding the flat catalog category."
diff --git app/locale/en_US/Mage_Core.csv app/locale/en_US/Mage_Core.csv
index 258a5f5d420..0e1fbcb3402 100644
--- app/locale/en_US/Mage_Core.csv
+++ app/locale/en_US/Mage_Core.csv
@@ -136,6 +136,7 @@
 "If the current frame position does not cover utmost pages, will render link to current position plus/minus this value.","If the current frame position does not cover utmost pages, will render link to current position plus/minus this value."
 "Incorrect credit card expiration date.","Incorrect credit card expiration date."
 "Input type ""%value%"" not found in the input types list.","Input type ""%value%"" not found in the input types list."
+"Invalid URL scheme.","Invalid URL scheme."
 "Invalid base url type","Invalid base url type"
 "Invalid block name to set child %s: %s","Invalid block name to set child %s: %s"
 "Invalid block type: %s","Invalid block type: %s"
@@ -143,6 +144,7 @@
 "Invalid connection","Invalid connection"
 "Invalid layout update handle","Invalid layout update handle"
 "Invalid messages storage ""%s"" for layout messages initialization","Invalid messages storage ""%s"" for layout messages initialization"
+"Invalid stream.","Invalid stream."
 "Invalid query","Invalid query"
 "Invalid transactional email code: ","Invalid transactional email code: "
 "Invalid website\'s configuration path: %s","Invalid website\'s configuration path: %s"
diff --git app/locale/en_US/Mage_Rss.csv app/locale/en_US/Mage_Rss.csv
index 64ae2f3a63c..815bc0dc93d 100644
--- app/locale/en_US/Mage_Rss.csv
+++ app/locale/en_US/Mage_Rss.csv
@@ -16,6 +16,7 @@
 "Discount","Discount"
 "Discount (%s)","Discount (%s)"
 "Enable RSS","Enable RSS"
+"Enabling can increase security risk by exposing some order details.", "Enabling can increase security risk by exposing some order details."
 "Error in processing xml. %s","Error in processing xml. %s"
 "From:","From:"
 "Get Feed","Get Feed"
diff --git app/locale/en_US/Mage_Widget.csv app/locale/en_US/Mage_Widget.csv
index edd41fcee7a..30fe29659e5 100644
--- app/locale/en_US/Mage_Widget.csv
+++ app/locale/en_US/Mage_Widget.csv
@@ -6,6 +6,7 @@
 "All","All"
 "All Pages","All Pages"
 "All Product Types","All Product Types"
+"An error occurred during POST data validation: %s","An error occurred during POST data validation: %s"
 "Anchor Categories","Anchor Categories"
 "Assign to Store Views","Assign to Store Views"
 "Big Image","Big Image"
diff --git lib/Varien/Db/Adapter/Pdo/Mysql.php lib/Varien/Db/Adapter/Pdo/Mysql.php
index a688695dd05..251b4359848 100644
--- lib/Varien/Db/Adapter/Pdo/Mysql.php
+++ lib/Varien/Db/Adapter/Pdo/Mysql.php
@@ -2662,7 +2662,7 @@ class Varien_Db_Adapter_Pdo_Mysql extends Zend_Db_Adapter_Pdo_Mysql implements V
                 if (isset($condition['to'])) {
                     $query .= empty($query) ? '' : ' AND ';
                     $to     = $this->_prepareSqlDateCondition($condition, 'to');
-                    $query = $this->_prepareQuotedSqlCondition($query . $conditionKeyMap['to'], $to, $fieldName);
+                    $query = $query . $this->_prepareQuotedSqlCondition($conditionKeyMap['to'], $to, $fieldName);
                 }
             } elseif (array_key_exists($key, $conditionKeyMap)) {
                 $value = $condition[$key];
diff --git lib/Varien/Filter/Template.php lib/Varien/Filter/Template.php
index c5045edf47d..0931426d0e7 100644
--- lib/Varien/Filter/Template.php
+++ lib/Varien/Filter/Template.php
@@ -234,6 +234,8 @@ class Varien_Filter_Template implements Zend_Filter_Interface
         $stackVars = $tokenizer->tokenize();
         $result = $default;
         $last = 0;
+        /** @var $emailPathValidator Mage_Adminhtml_Model_Email_PathValidator */
+        $emailPathValidator = $this->getEmailPathValidator();
         for($i = 0; $i < count($stackVars); $i ++) {
             if ($i == 0 && isset($this->_templateVars[$stackVars[$i]['name']])) {
                 // Getting of template value
@@ -252,10 +254,16 @@ class Varien_Filter_Template implements Zend_Filter_Interface
                     }
                 } else if ($stackVars[$i]['type'] == 'method') {
                     // Calling of object method
-                    if (is_callable(array($stackVars[$i-1]['variable'], $stackVars[$i]['name'])) || substr($stackVars[$i]['name'],0,3) == 'get') {
-                        $stackVars[$i]['variable'] = call_user_func_array(array($stackVars[$i-1]['variable'],
-                                                                                $stackVars[$i]['name']),
-                                                                          $stackVars[$i]['args']);
+                    if (is_callable(array($stackVars[$i-1]['variable'], $stackVars[$i]['name'])) || substr($stackVars[$i]['name'],0,3) == 'get')
+                    {
+                        $isEncrypted = false;
+                        if ($stackVars[$i]['name'] == 'getConfig') {
+                            $isEncrypted = $emailPathValidator->isValid($stackVars[$i]['args']);
+                        }
+                        $stackVars[$i]['variable'] = call_user_func_array(
+                            array($stackVars[$i-1]['variable'], $stackVars[$i]['name']),
+                            !$isEncrypted ? $stackVars[$i]['args'] : array(null)
+                        );
                     }
                 }
                 $last = $i;
@@ -269,4 +277,14 @@ class Varien_Filter_Template implements Zend_Filter_Interface
         Varien_Profiler::stop("email_template_proccessing_variables");
         return $result;
     }
+
+    /**
+     * Retrieve model object
+     *
+     * @return Mage_Core_Model_Abstract
+     */
+    protected function getEmailPathValidator()
+    {
+        return Mage::getModel('adminhtml/email_pathValidator');
+    }
 }
