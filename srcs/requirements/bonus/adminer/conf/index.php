<?php
$user = getenv('MYSQL_USER');
header('Location: /adminer.php?server=inception_mariadb&username=' . rawurlencode($user));