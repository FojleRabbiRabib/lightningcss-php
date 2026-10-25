--TEST--
Extension loads and registers its base surface
--SKIPIF--
<?php if (!extension_loaded('lightningcss')) die('skip lightningcss extension not loaded'); ?>
--FILE--
<?php
/* Copyright 2026 Fojle Rabbi (Rabib)
 * SPDX-License-Identifier: Apache-2.0 */
declare(strict_types=1);

var_dump(extension_loaded('lightningcss'));
var_dump(class_exists('Lightningcss\Exception'));
var_dump(is_subclass_of('Lightningcss\Exception', 'RuntimeException'));
echo ini_get('lightningcss.max_input_bytes'), PHP_EOL;
?>
--EXPECT--
bool(true)
bool(true)
bool(true)
16777216
