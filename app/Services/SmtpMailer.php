<?php
declare(strict_types=1);

namespace App\Services;

use RuntimeException;

/** Reusable plain-text SMTP sender. Credentials are read only from the environment. */
final class SmtpMailer
{
    public function send(string $recipient, string $subject, string $body): void
    {
        $host = (string)app_env('SMTP_HOST', '');
        $port = (int)app_env('SMTP_PORT', '587');
        $user = (string)app_env('SMTP_USERNAME', '');
        $pass = (string)app_env('SMTP_PASSWORD', '');
        $from = (string)app_env('SMTP_FROM_ADDRESS', '');
        $security = strtolower((string)app_env('SMTP_ENCRYPTION', 'tls'));
        if ($host === '' || $port < 1 || $port > 65535 || $from === '' || !filter_var($from, FILTER_VALIDATE_EMAIL)
            || !filter_var($recipient, FILTER_VALIDATE_EMAIL) || !in_array($security, ['tls', 'ssl'], true)) {
            throw new RuntimeException('SMTP configuration is incomplete or invalid.');
        }
        if (($user === '') !== ($pass === '')) throw new RuntimeException('SMTP authentication configuration is incomplete.');
        $timeout = 10;
        $context = stream_context_create(['ssl' => ['verify_peer' => true, 'verify_peer_name' => true]]);
        $target = ($security === 'ssl' ? 'ssl://' : 'tcp://') . $host . ':' . $port;
        $socket = @stream_socket_client($target, $errno, $error, $timeout, STREAM_CLIENT_CONNECT, $context);
        if (!$socket) throw new RuntimeException('SMTP connection failed: ' . $error);
        stream_set_timeout($socket, $timeout);
        try {
            $this->expect($socket, [220]);
            $hello = gethostname() ?: 'localhost';
            $this->command($socket, 'EHLO ' . $hello, [250]);
            if ($security === 'tls') {
                $this->command($socket, 'STARTTLS', [220]);
                if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                    throw new RuntimeException('SMTP TLS negotiation failed.');
                }
                $this->command($socket, 'EHLO ' . $hello, [250]);
            }
            if ($user !== '') {
                $this->command($socket, 'AUTH LOGIN', [334]);
                $this->command($socket, base64_encode($user), [334]);
                $this->command($socket, base64_encode($pass), [235]);
            }
            $this->command($socket, 'MAIL FROM:<' . $from . '>', [250]);
            $this->command($socket, 'RCPT TO:<' . $recipient . '>', [250, 251]);
            $this->command($socket, 'DATA', [354]);
            $cleanSubject = str_replace(["\r", "\n"], '', $subject);
            $message = "From: <{$from}>\r\nTo: <{$recipient}>\r\nSubject: {$cleanSubject}\r\n"
                . "MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n"
                . "Content-Transfer-Encoding: 8bit\r\n\r\n";
            $normalized = str_replace(["\r\n", "\r"], "\n", $body);
            $message .= implode("\r\n", array_map(static fn(string $line): string => str_starts_with($line, '.') ? '.' . $line : $line, explode("\n", $normalized)));
            fwrite($socket, $message . "\r\n.\r\n");
            $this->expect($socket, [250]);
            $this->command($socket, 'QUIT', [221]);
        } finally {
            fclose($socket);
        }
    }

    private function command($socket, string $command, array $codes): void
    {
        if (fwrite($socket, $command . "\r\n") === false) throw new RuntimeException('SMTP write failed.');
        $this->expect($socket, $codes);
    }

    private function expect($socket, array $codes): void
    {
        do {
            $line = fgets($socket, 4096);
            if ($line === false) throw new RuntimeException('SMTP server did not respond.');
            $code = (int)substr($line, 0, 3);
        } while (strlen($line) >= 4 && $line[3] === '-');
        if (!in_array($code, $codes, true)) throw new RuntimeException('SMTP server rejected the request (' . $code . ').');
    }
}
