#pragma once
#include <stdint.h>
#ifdef WIN32
#include <winsock2.h>
typedef SOCKET socket_t;
#else
#include <sys/types.h>
#include <sys/socket.h>
#include <unistd.h>
#define INVALID_SOCKET -1
typedef int socket_t;
#endif


class TcpServer {
public:
    TcpServer();
    ~TcpServer();
    int init(uint16_t port);
    int end();
    int listen(bool blocking = true);
    void close_listen() { close(m_listen_socket); };
    void close_client() { close(m_client_socket); };
    int accept();
    int recv(void *ptr_buf, size_t size, bool blocking = true);
    int send(const void *ptr_buf, size_t size);
    bool is_listening() { return (bool)(m_listen_socket > 0); };
    bool is_connected() { return (bool)(m_client_socket > 0); };
private:
    int set_blocking(socket_t fd, bool blocking);
    int close(socket_t socket) {
#ifdef WIN32
        return ::closesocket(socket);
#else
        return ::close(socket);
#endif
    };
private:
    socket_t m_listen_socket, m_client_socket;
};
